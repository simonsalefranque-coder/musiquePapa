/* Read-only DOM extraction. No network, page mutation, hidden application state or script execution.
   Adapters describe markup, never song titles, lyrics or chord sequences. */
(options => {
    const opt = options || {};
    const chordRE = /^(?:[A-G][#b♯♭]?(?:(?:maj|Maj|min|Min|dim|aug|sus|add|omit|alt|dom|no|m|M|Δ|ø|°|\+|-)|\d|[#b♯♭]|[(),.])*(?:\/(?:[A-G][#b♯♭]?|\d+))?|N\.?C\.?)$/;
    const validChord = s => s.length <= 60 && chordRE.test(s);
    const omit = 'nav,header,footer,aside,button,select,input,textarea,script,style,noscript,iframe,svg,canvas,[role="navigation"],[role="menu"],[role="dialog"],.ads,.advertisement,.ad-container,.chord-diagrams,.diagrams,.transpose,.tonality,.key-selector';
    const markerSelector = '[data-chord],.chord,.chord-name,.chord-symbol,.accord,.a[data-aff]';
    const box = e => { const r = e.getBoundingClientRect(); return {x:r.left+scrollX,y:r.top+scrollY,width:r.width,height:r.height}; };
    const visible = e => {
        for (let n=e;n && n!==document.documentElement;n=n.parentElement) {
            const c=getComputedStyle(n);
            if (n.hidden || c.display==='none' || c.visibility==='hidden' || c.visibility==='collapse' || Number(c.opacity)===0) return false;
        }
        return true;
    };
    const excluded = e => !!e.closest(omit) || !visible(e);
    const content = (e,pseudo) => {
        const style=getComputedStyle(e,pseudo);
        if(style.display==='none' || style.visibility==='hidden') return '';
        const value=style.content;
        if (!value || ['none','normal','""',"''"].includes(value)) return '';
        // Only CSS strings actually rendered; never evaluate CSS or arbitrary attributes.
        if (value.startsWith('"') && value.endsWith('"')) { try { return JSON.parse(value); } catch (_) { return value.slice(1,-1); } }
        return '';
    };
    const chordValue = e => {
        const rendered=(e.innerText||'').trim();
        const before=content(e,'::before').trim(), after=content(e,'::after').trim();
        if (validChord(rendered)) return rendered;
        if (validChord(before)) return before;
        if (validChord(after)) return after;
        // data-chord alone is a hint, not proof that an invisible chord is displayed.
        return '';
    };
    const warnings=[]; let detected=0, uncertain=0;
    const clean = s => s.replace(/[{}\r\n]/g,' ').trim();
    const section = s => /^\[?(refrain|chorus|couplet|verse|intro|pont|bridge|outro)(\s*\d*)?\]?:?$/i.test(s.trim());
    function sections(lines) {
        let opened=null, tab=false; const result=[];
        for (const line of lines) {
            if (line==='{{TAB_START}}') { result.push('{start_of_tab}'); tab=true; continue; }
            if (line==='{{TAB_END}}') { result.push('{end_of_tab}'); tab=false; continue; }
            if (!tab && section(line)) {
                if(opened) result.push('{end_of_'+opened+'}');
                opened=/refrain|chorus/i.test(line)?'chorus':/couplet|verse/i.test(line)?'verse':null;
                result.push(opened?'{start_of_'+opened+': '+clean(line)+'}':'{comment: '+clean(line)+'}');
            } else result.push(line);
        }
        if(opened) result.push('{end_of_'+opened+'}');
        return result.join('\n');
    }
    let root=null, strategy='', selectionRange=null;
    const selected=window.getSelection();
    if(selected && selected.rangeCount && !selected.isCollapsed) {
        selectionRange=selected.getRangeAt(0);
        root=selectionRange.commonAncestorContainer;
        if(root.nodeType!==Node.ELEMENT_NODE) root=root.parentElement;
        strategy='Sélection manuelle';
    }
    const isBAC=/(^|\.)boiteachansons\.net$/i.test(location.hostname);
    const bacRoot=document.getElementById('divPartition');
    if(!root && isBAC && bacRoot && visible(bacRoot)) { root=bacRoot; strategy='La Boîte à chansons · partition structurée'; }
    if(!root) {
        const candidates=Array.from(document.querySelectorAll('pre,[data-song],.chord-sheet,.chordsheet,.song-sheet,.song-content,.song-body,.lyrics,.chords,#song,#lyrics,[itemprop="lyrics"],article,main'));
        let best=-1;
        for(const e of candidates) {
            if(excluded(e)) continue;
            const marks=Array.from(e.querySelectorAll(markerSelector)).filter(n=>!excluded(n) && chordValue(n));
            const text=e.innerText||'';
            const chordLines=text.split('\n').filter(l=> { const t=l.trim().split(/[\s|]+/).filter(Boolean);return t.length && t.every(validChord); }).length;
            const bracketCount=(text.match(/\[[A-G][^\]\n]*\]/g)||[]).length;
            if(!marks.length && !chordLines && !bracketCount) continue;
            const linkText=Array.from(e.querySelectorAll('a')).reduce((n,a)=>n+(a.innerText||'').length,0);
            if(linkText>Math.max(20,text.length*.3)) continue;
            const score=marks.length*12+chordLines*6+bracketCount*8+Math.min(text.length,2000)/200-(e.querySelectorAll('nav,aside,select,button').length*5);
            if(score>best) { best=score;root=e;strategy=e.tagName==='PRE'?'Texte à colonnes conservées':'Partition générique · DOM et positions'; }
        }
    }
    if(!root) {
        if(!opt.allowWholePage) return {status:'no-region',message:'Aucune zone de partition fiable détectée. Sélectionnez la partition dans la page ou collez son texte.'};
        root=document.body; strategy='Contenu à corriger manuellement';
        warnings.push('Zone musicale non identifiée : le contenu récupéré peut encore contenir des éléments annexes.');
    }
    if((root.textContent||'').length>500000 || root.querySelectorAll('*').length>20000) return {status:'too-large',message:'La zone sélectionnée est trop grande. Sélectionnez seulement la partition.'};
    const selectedNode = n => !selectionRange || selectionRange.intersectsNode(n);
    const visibleText = e => !e || excluded(e) ? '' : (e.innerText||'').trim();
    let title='', artist='';
    if(isBAC) {
        title=visibleText(document.getElementById('dTitreChanson'));
        artist=visibleText(document.querySelector('.dTitreNomArtiste > a'));
    } else {
        title=visibleText(document.querySelector('[data-song-title],.song-title,[itemprop="name"],h1'));
        artist=visibleText(document.querySelector('[data-artist],.song-artist,.artist,[itemprop="byArtist"]'));
    }
    const rect=box(root);
    if(rect.width<=0 || rect.height<=0) return {status:'no-region',message:'Le contenu musical n’est pas visible. Affichez la partition avant de l’importer.'};
    let body='', plainText=null;
    if(isBAC && root===bacRoot && !selectionRange) {
        // The site places a zero-width sI anchor at the exact lyric character boundary.
        // Chord labels are CSS ::before content from data-aff, not text nodes.
        function musicalText(value) {
            // Six-string fingering annotations are presentation aids, not sung text.
            // Keep them in the immutable source PDF; do not treat them as lyrics or chords.
            const cleaned=value.replace(/\(\s*(?:[xX0-9]\s*){6}\)/g, '');
            const standalone=/^\s*(?:[xX0-9]\s*){6}\s*$/.test(cleaned);
            if(cleaned!==value || standalone) warnings.push('Indications de doigté exclues du ChordPro ; elles restent visibles dans la copie originale.');
            return standalone?'':cleaned;
        }
        function serialize(n) {
            if(n.nodeType===Node.TEXT_NODE) return musicalText(n.textContent);
            if(n.nodeType!==Node.ELEMENT_NODE || excluded(n)) return '';
            if(n.matches('.CALI2')) return ''; // Display-only fingering descriptions.
            if(n.matches('.a')) {
                const value=chordValue(n);
                if(value) { detected++; return '['+value+']'; }
                uncertain++;warnings.push('Un élément d’accord du site n’a pas de symbole lisible. Vérifiez cette ligne.');
                return '{comment: Accord du site à vérifier}';
            }
            if(n.tagName==='BR') return '\n';
            return Array.from(n.childNodes).map(serialize).join('');
        }
        const lines=[];let tabBlocks=[];
        function flushTabs() {
            if(!tabBlocks.length) return;
            const rows=[];
            for(const block of tabBlocks) for(const r of block.querySelectorAll('.tabR')) {
                const y=box(r).y;
                let row=rows.find(row=>Math.abs(row.y-y)<2);
                if(!row) { row={y,cells:[]};rows.push(row); }
                for(const c of r.children) {
                    if(!visible(c)) continue;
                    const text=(c.textContent||'').replace(/\s+/g,'');
                    const value=(c.classList.contains('tabB')?'|':'')+(text || (c.classList.contains('tabE')?'-':' '));
                    row.cells.push({x:box(c).x,value});
                }
            }
            lines.push('{{TAB_START}}');
            for(const row of rows.sort((a,b)=>a.y-b.y)) lines.push(row.cells.sort((a,b)=>a.x-b.x).map(c=>c.value).join(''));
            lines.push('{{TAB_END}}'); tabBlocks=[];
        }
        for(const n of root.childNodes) {
            if(n.nodeType===Node.ELEMENT_NODE && n.matches('.tabT')) { tabBlocks.push(n);continue; }
            if(n.nodeType===Node.TEXT_NODE && !n.textContent.trim()) continue;
            flushTabs();
            if(n.nodeType===Node.ELEMENT_NODE && n.matches('.CALI2')) continue;
            const value=serialize(n).replace(/\u00a0/g,' ').trim();
            lines.push(value);
        }
        flushTabs(); body=sections(lines);
    } else {
        const allElements=[root,...root.querySelectorAll('*')];
        const markers=new Map();
        let hints=0;
        for(const e of allElements) {
            if(excluded(e) || !selectedNode(e)) continue;
            const value=chordValue(e), explicit=e.matches(markerSelector);
            // A recognized pseudo-element is also an explicit visual chord hint.
            const pseudo=content(e,'::before') || content(e,'::after');
            if(explicit || validChord(pseudo.trim())) {
                hints++;
                if(value) markers.set(e,value);
                else { uncertain++; warnings.push('Un élément HTML suggère un accord sans symbole lisible : vérification nécessaire.'); }
            }
        }
        // Retain the outermost marked element once; nested chord spans must not duplicate.
        for(const e of markers.keys()) { for(let p=e.parentElement;p && root.contains(p);p=p.parentElement) if(markers.has(p)) { markers.delete(e);break; } }
        const isMonospace=['pre','pre-wrap','break-spaces'].includes(getComputedStyle(root).whiteSpace);
        if(!markers.size && !hints && isMonospace && !selectionRange && !root.querySelector('nav,aside,select,button')) {
            plainText=root.innerText; // Only an isolated preformatted musical region, never the full page.
            // Count the source independently of the Swift converter, including mixed layouts.
            let inTab=false;
            for(const line of plainText.split('\n')) {
                if(/^\s*\{(?:start_of_tab|sot)\}/i.test(line)) { inTab=true; continue; }
                if(/^\s*\{(?:end_of_tab|eot)\}/i.test(line)) { inTab=false; continue; }
                if(/^\s*[#{]/.test(line)) continue;
                if(inTab || /^\s*[eEBGDA]?\|[-0-9hpx/\\~().| ]{3,}/.test(line)) continue;
                const bracketed=Array.from(line.matchAll(/\[([^\]\n]+)\]/g)).filter(m=>validChord(m[1]));
                const tokens=line.trim().split(/[\s|]+/).filter(Boolean);
                detected+=bracketed.length || (tokens.length && tokens.every(validChord)?tokens.length:0);
            }
        } else {
            const atoms=[];let order=0, length=0;
            function append(text,rect,chord=false,instrumental=false) { atoms.push({text,...rect,chord,instrumental,order:order++}); }
            function walk(n) {
                if(!selectedNode(n)) return;
                if(n.nodeType===Node.ELEMENT_NODE) {
                    if(excluded(n)) return;
                    if(markers.has(n)) {
                        const r=box(n), value=markers.get(n);
                        if(r.height>0) { append(value,r,true,!!n.closest('.intro,.instrumental,[data-instrumental]'));detected++; }
                        else { uncertain++; warnings.push('Un accord sans position visuelle exploitable doit être vérifié : '+value); }
                        return;
                    }
                    for(const child of n.childNodes) walk(child);
                    return;
                }
                if(n.nodeType!==Node.TEXT_NODE) return;
                const parent=n.parentElement;
                if(!parent || excluded(parent)) return;
                const preserve=['pre','pre-wrap','break-spaces'].includes(getComputedStyle(parent).whiteSpace);
                const str=n.textContent;let offset=0;
                for(const char of str) {
                    const end=offset+char.length;
                    const range=document.createRange();range.setStart(n,offset);range.setEnd(n,end);
                    offset=end;
                    if(selectionRange) {
                        const start=selectionRange.cloneRange(), endRange=selectionRange.cloneRange();
                        start.collapse(true); endRange.collapse(false);
                        const glyphStart=range.cloneRange(), glyphEnd=range.cloneRange();
                        glyphStart.collapse(true); glyphEnd.collapse(false);
                        if(glyphEnd.compareBoundaryPoints(Range.START_TO_START,start)<=0 || glyphStart.compareBoundaryPoints(Range.START_TO_START,endRange)>=0) continue;
                    }
                    if(++length>100000) throw new Error('Zone trop longue : sélectionnez un extrait de la partition.');
                    const r=range.getBoundingClientRect();
                    if(r.width<=0 || r.height<=0 || (preserve && /[\r\n]/.test(char))) continue;
                    append(/\s/.test(char)?' ':char,{x:r.x+scrollX,y:r.y+scrollY,width:r.width,height:r.height});
                }
            }
            walk(root);
            const rows=[];
            for(const a of atoms.sort((a,b)=>(a.y+a.height/2)-(b.y+b.height/2) || a.order-b.order)) {
                let row=rows.find(r=>Math.abs(r.y+r.height/2-(a.y+a.height/2))<Math.max(2,Math.max(r.height,a.height)*.4));
                if(!row) { row={y:a.y,height:a.height,atoms:[]};rows.push(row); }
                row.atoms.push(a);
            }
            rows.sort((a,b)=>a.y-b.y);
            function sorted(r) { return r.atoms.sort((a,b)=>a.x-b.x||a.order-b.order); }
            function text(r) { return sorted(r).filter(a=>!a.chord).map(a=>a.text).join(''); }
            // Recognize separate plain chord rows as well as marked elements.
            for(const row of rows) {
                const inlineText=sorted(row).filter(a=>!a.chord).map(a=>a.text).join('');
                detected+=Array.from(inlineText.matchAll(/\[([^\]\n]+)\]/g)).filter(m=>validChord(m[1])).length;
                if(row.atoms.some(a=>a.chord)) continue;
                const glyphs=sorted(row), value=glyphs.map(a=>a.text).join('');
                const tokens=Array.from(value.matchAll(/[^\s|]+/g));
                if(tokens.length && tokens.every(t=>validChord(t[0]))) {
                    let cursor=0;const byUTF16=[];
                    for(const a of glyphs) { for(let i=0;i<a.text.length;i++) byUTF16[cursor++]=a; }
                    row.atoms=tokens.map(t=>({...byUTF16[t.index],text:t[0],chord:true,uncertain:tokens.length===1}));
                    detected+=tokens.length;
                    if(tokens.length===1) { uncertain++; warnings.push('Accord isolé reconnu dans du texte brut : vérifiez qu’il ne s’agit pas d’un mot.'); }
                }
            }
            const lines=[];
            function render(row,above=[]) {
                const glyphs=sorted(row).filter(a=>!a.chord), chords=[...above,...row.atoms.filter(a=>a.chord)].sort((a,b)=>a.x-b.x||a.order-b.order);
                const insertions=new Map();
                for(const a of chords) {
                    let index=glyphs.findIndex(g=>g.x+g.width/2>=a.x); if(index<0) index=glyphs.length;
                    // Nearest visible character boundary, only within this established visual line.
                    const boundary=index<glyphs.length?glyphs[index].x:(glyphs.at(-1)?.x+glyphs.at(-1)?.width||a.x);
                    if(glyphs.length && Math.abs(boundary-a.x)>Math.max(16,a.height)) { if(!a.uncertain) { uncertain++;a.uncertain=true; } warnings.push('Accord '+a.text+' éloigné des paroles : position à vérifier.'); }
                    if(!insertions.has(index)) insertions.set(index,[]);
                    insertions.get(index).push('['+a.text+']');
                }
                let line='';for(let i=0;i<=glyphs.length;i++) { line+=(insertions.get(i)||[]).join('');if(i<glyphs.length) line+=glyphs[i].text; }
                return line.trimEnd();
            }
            for(let i=0;i<rows.length;i++) {
                const row=rows[i], next=rows[i+1], chords=row.atoms.filter(a=>a.chord);
                if(i && row.y-(rows[i-1].y+rows[i-1].height)>row.height) lines.push('');
                if(chords.length && !text(row).trim()) {
                    if(next && text(next).trim() && !section(text(next)) && !/^[eEBGDA]?\|/.test(text(next).trim()) && next.y-row.y<=Math.max(row.height,next.height)*2.5 && !chords.some(c=>c.instrumental)) {
                        lines.push(render(next,chords));i++;
                    } else lines.push(chords.map(a=>'['+a.text+']').join(' '));
                } else {
                    const value=render(row);
                    if(/^[eEBGDA]?\|[-0-9hpx/\\~().| ]{3,}/.test(value.trim())) {
                        if(lines.at(-1)==='{{TAB_END}}') lines.pop(); else lines.push('{{TAB_START}}');
                        lines.push(value);lines.push('{{TAB_END}}');
                    } else lines.push(value);
                }
            }
            body=sections(lines);
        }
        if(selectionRange) warnings.push('Sélection manuelle : vérifiez que les accords situés aux bords de la sélection sont inclus.');
    }
    if(!plainText && !body.trim()) return {status:'no-region',message:'Aucun contenu musical exploitable dans cette zone.'};
    if(!plainText && detected===0) warnings.push('Aucun accord détecté dans le contenu. Si des accords sont visibles dans la page, cette conversion est incomplète.');
    return {status:'ok',title:title.slice(0,300),artist:artist.slice(0,300),body,plainText,detected,uncertain,warnings:[...new Set(warnings)],strategy,rect};
})(__OPTIONS__)
