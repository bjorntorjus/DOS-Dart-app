// DOSSEDART — X01 overview round (mode round 1/5 · 2026-07-22)
// Scope: ONE zone — the overview between TopBar and board. 272px budget.
// Today's card shown next to three proposals; stress states on the pick.
const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', LIME='#C6FF3C', PURPLE='#B15CFF',
      BG='#0a0014', SURFACE='#1a0030';
const INK='rgba(255,255,255,';
const PS='"Press Start 2P", monospace';
const VT='"VT323", monospace';
const W=820, H=1180, ZONE=272;

// ── data ────────────────────────────────────────────────────────
const P6=[
  {handle:'JON',name:'Jonas',accent:CYAN,remaining:60},
  {handle:'TOR',name:'Tor',accent:ORANGE,remaining:89},
  {handle:'LIV',name:'Live',accent:LIME,remaining:141,active:true},
  {handle:'MIA',name:'Mia',accent:YELLOW,remaining:218},
  {handle:'AND',name:'Andreas',accent:PURPLE,remaining:264},
  {handle:'PER',name:'Per',accent:GREEN,remaining:301},
];
const P4=[P6[0],P6[2],P6[3],P6[5]];
const MAX_STATE={players:P6,dartIdx:2,last:'T20 · 20 · —',lastSum:80,avg:'58.4',hit:'61%',checkout:'T20 T19 D12'};
const rank=(ps)=>{const s=[...ps].sort((a,b)=>a.remaining-b.remaining);const lead=s[0].remaining;const unique=s.filter(p=>p.remaining===lead).length===1;return{s,lead,unique};};
const nameSize=(n)=>n.length<=8?18:n.length<=12?15:n.length<=16?12:10;
// long names: cut the middle, keep start + end (rail is tightest)
const midTrunc=(n,max)=>n.length<=max?n:n.slice(0,Math.ceil((max-1)*0.6))+'…'+n.slice(n.length-Math.floor((max-1)*0.4));

// ── shared micro-parts (grammar rule 4) ─────────────────────────
const PhotoAvatar=({size,handle,accent})=>(
  <div style={{width:size,height:size,flexShrink:0,border:`2px solid ${accent}`,position:'relative',boxShadow:`0 0 12px ${accent}55`,
               background:`repeating-linear-gradient(135deg, #1c0033 0, #1c0033 4px, #130024 4px, #130024 8px)`,
               display:'flex',alignItems:'center',justifyContent:'center'}}>
    <span style={{fontFamily:VT,fontSize:size*0.4,color:INK+'0.42)',letterSpacing:1}}>{handle}</span>
    <span style={{position:'absolute',bottom:2,right:3,fontFamily:VT,fontSize:8,color:INK+'0.28)'}}>▨</span>
  </div>
);
const Pips=({accent,n})=>(
  <div style={{display:'flex',alignItems:'center',gap:9}}>
    <div style={{display:'flex',gap:6}}>
      {[0,1,2].map(i=>(<div key={i} style={{width:9,height:9,background:i<n?accent:'transparent',border:`2px solid ${i<n?accent:INK+'0.3)'}`,boxShadow:i<n?`0 0 6px ${accent}aa`:'none'}}/>))}
    </div>
    <span style={{fontFamily:VT,fontSize:15,color:INK+'0.5)',letterSpacing:1}}>DART {Math.min(n+1,3)}/3</span>
  </div>
);
const Header=({p,dartIdx})=>(
  <div style={{display:'flex',alignItems:'flex-start',gap:13}}>
    <PhotoAvatar size={56} handle={p.handle} accent={p.accent}/>
    <div style={{flex:1,minWidth:0,paddingTop:3}}>
      <div style={{fontFamily:PS,fontSize:nameSize(p.name),color:'#fff',letterSpacing:1.5,lineHeight:1.2,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{p.name.toUpperCase()}</div>
      <div style={{marginTop:10}}><Pips accent={p.accent} n={dartIdx}/></div>
    </div>
    <div style={{textAlign:'right'}}>
      <div style={{fontFamily:PS,fontSize:8,color:INK+'0.55)',letterSpacing:1.5}}>REMAINING</div>
      <div style={{fontFamily:PS,fontSize:60,color:p.accent,lineHeight:1,letterSpacing:-2,marginTop:4,textShadow:`0 0 16px ${p.accent}aa`}}>{p.remaining}</div>
    </div>
  </div>
);
// helper band — always rendered (grammar rule 2); cells dim when empty
const Cell=({label,value,color,flex=1,mono,dim,bg,glow})=>(
  <div style={{flex,minWidth:0,padding:'6px 12px',borderLeft:`1px solid ${INK}0.1)`,opacity:dim?0.34:1,background:bg||'transparent'}}>
    <div style={{fontFamily:PS,fontSize:7,color:INK+'0.45)',letterSpacing:1}}>{label}</div>
    <div style={{fontFamily:mono?PS:VT,fontSize:mono?11:18,color:color||'#fff',marginTop:mono?5:2,letterSpacing:1,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis',textShadow:glow?`0 0 6px ${color}`:'none'}}>{value}</div>
  </div>
);
const HelperBand=({s})=>(
  <div style={{display:'flex',alignItems:'stretch',border:`1px solid ${INK}0.12)`,borderLeft:'none',background:'rgba(0,0,0,0.25)'}}>
    <Cell label="LAST" value={s.last?`${s.last}  = ${s.lastSum}`:'— · — · —'} color={YELLOW} dim={!s.last}/>
    <Cell label="AVG" value={s.avg||'—'} dim={!s.avg}/>
    {s.checkout
      ? <Cell label="CHECKOUT" value={`▶ ${s.checkout}`} color={GREEN} mono flex={1.4} bg={`${GREEN}0e`} glow/>
      : <Cell label="CHECKOUT" value="— — —" flex={1.4} dim/>}
  </div>
);
// standings strip — Wildcard's proven shape, standardized (rule 7)
const Chips=({players,fill})=>{
  const{s,lead,unique}=rank(players);
  const compact=s.length>4;
  return (
    <div style={{display:'flex',gap:6,height:fill?'100%':36}}>
      {s.map((p,i)=>{
        const d=p.remaining-lead;
        const isLead=unique&&d===0;
        const flag=p.active?(d===0?(unique?'👑':null):`▲${d}`):(isLead?'👑':null);
        return (
          <div key={p.handle} style={{flex:1,minWidth:0,display:'flex',alignItems:'center',gap:compact?4:6,padding:compact?'0 6px':'0 8px',
                       border:`1px solid ${p.active?p.accent:INK+'0.14)'}`,background:p.active?`${p.accent}14`:'rgba(0,0,0,0.2)',opacity:p.active?1:0.78}}>
            {!compact&&<span style={{fontFamily:PS,fontSize:8,color:isLead?YELLOW:INK+'0.35)',flexShrink:0}}>{i+1}</span>}
            <span style={{width:7,height:7,background:p.accent,boxShadow:`0 0 5px ${p.accent}`,flexShrink:0}}/>
            <span style={{fontFamily:PS,fontSize:8,color:'#fff',letterSpacing:0.5,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis',flexShrink:compact?0:1}}>{(compact?p.handle:p.name).toUpperCase()}</span>
            <span style={{marginLeft:'auto',fontFamily:VT,fontSize:compact?16:20,color:p.accent,lineHeight:1,textShadow:`0 0 6px ${p.accent}66`,flexShrink:0}}>{p.remaining}</span>
            {flag&&(flag==='👑'
              ?<span style={{fontSize:11,flexShrink:0}}>👑</span>
              :<span style={{fontFamily:PS,fontSize:7,color:YELLOW,border:`1px solid ${YELLOW}`,padding:compact?'2px 3px':'2px 4px',flexShrink:0,letterSpacing:0.5,whiteSpace:'nowrap'}}>{flag}</span>)}
          </div>
        );
      })}
    </div>
  );
};
const StandingsRule=({note})=>(
  <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:6}}>
    <span style={{fontFamily:PS,fontSize:7,color:INK+'0.35)',letterSpacing:2}}>STANDINGS</span>
    <div style={{flex:1,height:1,background:INK+'0.1)'}}/>
    <span style={{fontFamily:VT,fontSize:13,color:INK+'0.35)',letterSpacing:1}}>{note||'LOWEST WINS · ▲ TO WIN'}</span>
  </div>
);

// ── card frame (grammar rule 5): surface fill · 3px accent · 14px glow
const cardFrame=(acc,h)=>({boxSizing:'border-box',height:h,margin:'12px 14px 10px',padding:'12px 14px',
  background:SURFACE,border:`3px solid ${acc}`,boxShadow:`0 0 14px ${acc}66`,display:'flex',flexDirection:'column',justifyContent:'space-between',position:'relative',zIndex:2});

// A — footer strip inside the card (recommended)
const CardA=({s})=>{const p=s.players.find(x=>x.active);return (
  <div style={cardFrame(p.accent,250)}>
    <Header p={p} dartIdx={s.dartIdx}/>
    <HelperBand s={s}/>
    <div><StandingsRule/><Chips players={s.players}/></div>
  </div>
);};
// B — standings rail on the right (CHOSEN) · rail includes active player,
// leftover width feeds oche-legible LAST/AVG/CHECKOUT rows
const CardB=({s})=>{
  const p=s.players.find(x=>x.active);
  const{s:sorted,lead,unique}=rank(s.players);
  const d=p.remaining-lead;
  return (
    <div style={cardFrame(p.accent,250)}>
      <Header p={p} dartIdx={s.dartIdx}/>
      <div style={{flex:1,minHeight:0,display:'flex',gap:14,marginTop:8}}>
        <div style={{flex:1,minWidth:0,display:'flex',flexDirection:'column',justifyContent:'flex-end'}}>
          {[['LAST',s.last?`${s.last}  = ${s.lastSum}`:'— · — · —',YELLOW,!s.last,false],['AVG',s.avg||'—','#fff',!s.avg,false],
            ['CHECKOUT',s.checkout?`▶ ${s.checkout}`:'— — —',GREEN,!s.checkout,true]].map(([l,v,c,dim,mono])=>(
            <div key={l} style={{display:'flex',alignItems:'center',gap:12,padding:'6px 2px',borderTop:`1px solid ${INK}0.1)`,opacity:dim?0.34:1,minHeight:38}}>
              <span style={{fontFamily:PS,fontSize:9,color:INK+'0.5)',letterSpacing:1,width:88,flexShrink:0}}>{l}</span>
              <span style={{fontFamily:mono&&!dim?PS:VT,fontSize:mono&&!dim?14:26,color:dim?'#fff':c,letterSpacing:1,lineHeight:1,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis',textShadow:dim?'none':`0 0 8px ${c}66`}}>{v}</span>
              {l==='AVG'&&(
                <React.Fragment>
                  <span style={{fontFamily:PS,fontSize:9,color:INK+'0.5)',letterSpacing:1,marginLeft:22,flexShrink:0}}>HIT%</span>
                  <span style={{fontFamily:VT,fontSize:26,color:s.hit?CYAN:'#fff',letterSpacing:1,lineHeight:1,flexShrink:0,opacity:s.hit?1:0.34,textShadow:s.hit?`0 0 8px ${CYAN}66`:'none'}}>{s.hit||'—'}</span>
                </React.Fragment>
              )}
            </div>))}
        </div>
        <div style={{width:300,flexShrink:0,borderLeft:`1px solid ${INK}0.12)`,paddingLeft:12,display:'flex',flexDirection:'column'}}>
          {sorted.map((o,i)=>{const isLead=unique&&o.remaining===lead;return (
            <div key={o.handle} style={{display:'flex',alignItems:'center',gap:7,padding:'1px 5px 1px 6px',borderLeft:o.active?`3px solid ${o.accent}`:'3px solid transparent',background:o.active?`${o.accent}16`:'transparent',opacity:o.active?1:0.75,flex:1,minHeight:0}}>
              <span style={{fontFamily:PS,fontSize:7,color:isLead?YELLOW:INK+'0.35)',width:10,flexShrink:0}}>{i+1}</span>
              <span style={{width:7,height:7,background:o.accent,boxShadow:`0 0 5px ${o.accent}`,flexShrink:0}}/>
              <span style={{fontFamily:PS,fontSize:8,color:o.active?'#fff':INK+'0.8)',letterSpacing:0.5,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{midTrunc(o.name.toUpperCase(),16)}</span>
              {isLead&&<span style={{fontSize:10,flexShrink:0}}>👑</span>}
              <span style={{marginLeft:'auto',fontFamily:VT,fontSize:18,color:o.accent,lineHeight:1,flexShrink:0,textShadow:`0 0 6px ${o.accent}55`}}>{o.remaining}</span>
            </div>);})}
          <div style={{display:'flex',alignItems:'center',gap:8,paddingTop:4,marginTop:3,borderTop:`1px solid ${INK}0.1)`}}>
            <span style={{fontFamily:PS,fontSize:8,color:INK+'0.5)',letterSpacing:1}}>TO WIN</span>
            <span style={{marginLeft:'auto',fontFamily:PS,fontSize:13,color:YELLOW,textShadow:`0 0 8px ${YELLOW}88`}}>{d===0?(unique?'YOU LEAD':'TIED'):`▲ ${d}`}</span>
          </div>
        </div>
      </div>
    </div>
  );
};
// C — slim card + standalone strip below (Wildcard-literal)
const CardC=({s})=>{const p=s.players.find(x=>x.active);return (
  <React.Fragment>
    <div style={{...cardFrame(p.accent,196),margin:'12px 14px 8px'}}>
      <Header p={p} dartIdx={s.dartIdx}/>
      <HelperBand s={s}/>
    </div>
    <div style={{height:46,margin:'0 14px',position:'relative',zIndex:2}}><Chips players={s.players} fill/></div>
  </React.Fragment>
);};

// ── chrome ──────────────────────────────────────────────────────
const scan=`repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const TopBar=()=>(
  <div style={{padding:'15px 22px',background:'#000',borderBottom:`2px solid ${MAGENTA}`,display:'flex',alignItems:'center',gap:14,position:'relative',zIndex:6}}>
    <div style={{fontFamily:VT,fontSize:19,color:CYAN,letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1,textAlign:'center',fontFamily:PS,fontSize:12,color:YELLOW,letterSpacing:2,textShadow:`0 0 8px ${YELLOW}88`}}>X01 · 501 · D-OUT</div>
    <div style={{fontFamily:VT,fontSize:17,color:INK+'0.55)',letterSpacing:2}}>L 1/3 · RND 7</div>
  </div>
);
const Ruler=({label})=>(
  <div style={{position:'absolute',top:0,bottom:0,right:2,width:13,borderTop:`1px solid ${YELLOW}99`,borderBottom:`1px solid ${YELLOW}99`,borderRight:`1px solid ${YELLOW}99`,zIndex:7,pointerEvents:'none'}}>
    <span style={{position:'absolute',top:'50%',right:2,transform:'translateY(-50%)',writingMode:'vertical-rl',fontFamily:PS,fontSize:6,color:YELLOW,letterSpacing:1}}>{label}</span>
  </div>
);
const BoardSlice=({offset=14,note})=>(
  <div style={{position:'relative',flex:1,overflow:'hidden'}}>
    <div style={{position:'absolute',left:'50%',top:offset,transform:'translateX(-50%)',width:420,height:420,borderRadius:'50%',border:`2px dashed ${INK}0.22)`,background:`radial-gradient(circle, rgba(255,0,170,0.1) 0%, transparent 68%)`,display:'flex',justifyContent:'center'}}>
      <span style={{marginTop:34,fontFamily:PS,fontSize:9,color:INK+'0.38)',letterSpacing:2}}>◎ BOARD{note?` · ${note}`:''}</span>
    </div>
  </div>
);
const ZoneFrame=({children})=>(
  <div style={{width:W,height:460,background:BG,color:'#fff',fontFamily:PS,overflow:'hidden',position:'relative',display:'flex',flexDirection:'column'}}>
    <div style={{position:'absolute',inset:0,backgroundImage:scan,pointerEvents:'none',zIndex:5}}></div>
    <TopBar/>
    <div style={{height:ZONE,flexShrink:0,position:'relative',borderBottom:`1px dashed ${INK}0.18)`}}>
      {children}
      <Ruler label="OVERVIEW · 272 PX"/>
    </div>
    <BoardSlice note="TOP EDGE FIXED"/>
  </div>
);

// ── TODAY — faithful to x01-cockpit-final.jsx ActiveCard ────────
const TodayCard=({p,checkout})=>(
  <div style={{margin:'14px 14px 0',padding:'14px 18px',position:'relative',zIndex:2,border:`3px solid ${p.accent}`,
               background:`linear-gradient(180deg, ${p.accent}1a 0%, ${p.accent}05 100%)`,boxShadow:`0 0 16px ${p.accent}40`}}>
    <div style={{position:'absolute',top:-9,left:18,padding:'3px 9px',background:p.accent,color:BG,fontFamily:PS,fontSize:9,letterSpacing:1.5,boxShadow:`0 0 8px ${p.accent}aa`}}>▶ NOW THROWING</div>
    <div style={{display:'flex',alignItems:'flex-start',gap:14}}>
      <div style={{width:56,height:56,background:BG,border:`3px solid ${p.accent}`,display:'flex',alignItems:'center',justifyContent:'center',fontFamily:PS,fontSize:15,color:p.accent,textShadow:`0 0 8px ${p.accent}aa`,flexShrink:0,boxShadow:`0 0 12px ${p.accent}55`}}>{p.handle}</div>
      <div style={{flex:1,minWidth:0}}>
        <div style={{fontFamily:PS,fontSize:18,color:'#fff',letterSpacing:2,lineHeight:1,marginTop:4}}>{p.name.toUpperCase()}</div>
        <div style={{display:'flex',alignItems:'center',gap:10,marginTop:8}}>
          <div style={{display:'flex',gap:6}}>{[0,1,2].map(i=>(<div key={i} style={{width:10,height:10,background:i<p.dartIdx?p.accent:'transparent',border:`2px solid ${p.accent}`,boxShadow:i<p.dartIdx?`0 0 6px ${p.accent}aa`:'none'}}></div>))}</div>
          <div style={{fontFamily:VT,fontSize:14,color:INK+'0.55)',letterSpacing:1}}>DART {p.dartIdx}/3</div>
        </div>
      </div>
      <div style={{textAlign:'right'}}>
        <div style={{fontFamily:PS,fontSize:9,color:INK+'0.6)',letterSpacing:1.5}}>REMAINING</div>
        <div style={{fontFamily:PS,fontSize:58,color:p.accent,lineHeight:1,textShadow:`0 0 16px ${p.accent}aa`,letterSpacing:-2,marginTop:4}}>{p.remaining}</div>
      </div>
    </div>
    <div style={{display:'flex',alignItems:'center',gap:8,marginTop:10,padding:'8px 12px',borderTop:`1px solid ${p.accent}66`}}>
      <div style={{fontFamily:PS,fontSize:9,color:INK+'0.6)',letterSpacing:1.5}}>LAST</div>
      <div style={{flex:1,textAlign:'center',fontFamily:VT,fontSize:20,color:YELLOW,letterSpacing:1.5}}>{p.last}</div>
      <div style={{fontFamily:PS,fontSize:13,color:YELLOW,letterSpacing:1}}>= {p.lastSum}</div>
    </div>
    {checkout&&(
      <div style={{marginTop:10,padding:'8px 10px',background:`${GREEN}10`,border:`2px solid ${GREEN}`,boxShadow:`0 0 14px ${GREEN}40`,textAlign:'center'}}>
        <span style={{fontFamily:PS,fontSize:10,color:GREEN,letterSpacing:1}}>▶ {checkout}</span>
      </div>
    )}
  </div>
);
const TodayFrame=({p,checkout,jumpNote})=>(
  <div style={{width:W,height:460,background:BG,color:'#fff',fontFamily:PS,overflow:'hidden',position:'relative',display:'flex',flexDirection:'column'}}>
    <div style={{position:'absolute',inset:0,backgroundImage:scan,pointerEvents:'none',zIndex:5}}></div>
    <TopBar/>
    <TodayCard p={p} checkout={checkout}/>
    {jumpNote&&(
      <div style={{position:'relative',zIndex:6,margin:'0 14px',borderTop:`2px dashed ${RED}aa`,paddingTop:4,textAlign:'right'}}>
        <span style={{fontFamily:PS,fontSize:7,color:RED,letterSpacing:1}}>{jumpNote}</span>
      </div>
    )}
    <BoardSlice note="TOP EDGE MOVES"/>
  </div>
);

// ── full cockpit (proposal A) ───────────────────────────────────
const ActionBar=()=>(
  <div style={{position:'absolute',left:0,right:0,bottom:0,padding:'13px 16px 17px',background:'#000',borderTop:`2px solid ${YELLOW}`,display:'flex',gap:12,zIndex:6}}>
    <div style={{flex:1,padding:'16px 8px',border:`2px solid ${MAGENTA}`,fontFamily:PS,fontSize:12,color:'#fff',letterSpacing:1,textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:2,padding:'16px 8px',background:ORANGE,border:'2px solid #fff',fontFamily:PS,fontSize:12,color:BG,letterSpacing:2,textAlign:'center',boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:1,padding:'16px 8px',border:`2px solid ${CYAN}`,fontFamily:PS,fontSize:12,color:CYAN,letterSpacing:1,textAlign:'center'}}>⋯ MENU</div>
  </div>
);
const FullCockpit=({s})=>(
  <div style={{width:W,height:H,background:BG,color:'#fff',fontFamily:PS,display:'flex',flexDirection:'column',overflow:'hidden',position:'relative'}}>
    <div style={{position:'absolute',inset:0,backgroundImage:scan,pointerEvents:'none',zIndex:5}}></div>
    <div style={{position:'absolute',inset:0,background:'radial-gradient(ellipse at center, transparent 52%, rgba(0,0,0,0.62) 100%)',pointerEvents:'none',zIndex:4}}></div>
    <TopBar/>
    <div style={{height:ZONE,flexShrink:0,position:'relative'}}><CardB s={s}/><Ruler label="272 PX"/></div>
    <div style={{flex:1,position:'relative',display:'flex',alignItems:'center',justifyContent:'center',paddingBottom:84}}>
      <div style={{position:'absolute',width:520,height:520,borderRadius:'50%',background:'radial-gradient(circle, rgba(255,0,170,0.16) 0%, transparent 68%)',pointerEvents:'none'}}/>
      <div style={{width:430,height:430,borderRadius:'50%',border:`2px dashed ${INK}0.2)`,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:9}}>
        <div style={{fontFamily:PS,fontSize:12,color:INK+'0.4)',letterSpacing:2}}>◎ DARTBOARD</div>
        <div style={{fontFamily:VT,fontSize:17,color:INK+'0.32)',letterSpacing:1}}>approved chrome · out of scope</div>
      </div>
    </div>
    <ActionBar/>
  </div>
);

// ── spec / fasit ────────────────────────────────────────────────
const SRow=({k,v})=>(
  <div style={{display:'flex',gap:12,padding:'7px 0',borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{width:158,flexShrink:0,fontFamily:'"Inter",sans-serif',fontSize:12,fontWeight:800,color:'#2a251f'}}>{k}</div>
    <div style={{flex:1,fontFamily:'"Inter",sans-serif',fontSize:12,lineHeight:1.45,color:'#5a544a'}}>{v}</div>
  </div>
);
const SpecCard=()=>(
  <div style={{boxSizing:'border-box',width:720,height:H,background:'#fffdf6',border:'1.5px solid rgba(0,0,0,0.14)',padding:'30px 34px',fontFamily:'"Inter",system-ui,sans-serif',display:'flex',flexDirection:'column',gap:14,overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono",monospace',fontSize:11,letterSpacing:2,color:'#c96442',textTransform:'uppercase',fontWeight:600,marginBottom:6}}>X01 overview · mode round 1/5 · fasit</div>
      <div style={{fontFamily:'"Archivo","Inter",sans-serif',fontSize:25,fontWeight:900,letterSpacing:-0.5,color:'#2a251f',lineHeight:1.1}}>Forslag B — standings-skinne til høyre (valgt)</div>
    </div>
    <div style={{padding:'12px 14px',background:'#2a251f'}}>
      <div style={{fontFamily:'"JetBrains Mono",monospace',fontSize:13,fontWeight:700,color:'#C6FF3C',lineHeight:1.5}}>OVERVIEW ZONE: h=272 px @ 820×1180 — all states fit, no growth</div>
    </div>
    <div>
      <SRow k="Sone → kort" v="Kort 250px fast + marger 14/12/14/10. Kortet vokser ALDRI: helper-band og standings er alltid rendret, dimmet (opacity 0.34) uten innhold."/>
      <SRow k="Kort-ramme (regel 5)" v={<span>Fill <b>surface #1A0030</b> (gradienten fra dagens kort utgår) · 3px border i <b>spillerens accent</b> · 14px accent-glow · padding 14/12/14/12. NOW THROWING-badgen utgår — accent + navn bærer det.</span>}/>
      <SRow k="Header (regel 4)" v="Avatar 56px foto (silhuett-fallback) · navn-kurve 18/15/12/10 etter lengde · tre 9px dart-pips + DART n/3."/>
      <SRow k="Primærtall (regel 6)" v="REMAINING 60px Press Start 2P i spiller-accent m/ glow. Eneste primærtall på kortet."/>
      <SRow k="LAST / AVG / CHECKOUT" v="Tre stablede rader i venstre kolonne, oche-lesbare: label PS-9 + verdi VT-26. LAST gul m/ sum · AVG hvit + HIT% cyan i samme rad (PROPOSAL — treff på siktet felt denne legen; impl. eier måledefinisjonen). Checkout: grønn PS-14 m/ glow når ≤170; ellers «— — —» dimmet. Første dart: alt dimmet med placeholder."/>
      <SRow k="Standings (regel 7)" v={<span>Høyre skinne 300px: ALLE spillere sortert stigende remaining — inkl. den aktive (accent-border + accent-bakgrunn) så hen ser egen plass i hierarkiet. Rad = rang + accent-dot + navn + remaining VT-18. 👑 på unik leder. Bunnrad: <b>TO WIN ▲n</b>-delta mot leder (in-scope ask, ikke PROPOSAL).</span>}/>
      <SRow k="Stress: navn" v="Navn-kurven bunner på 10px ved >16 tegn. Lengre navn («Alexander the boss bitch», 24 tegn): header viser mest mulig (der er det plass når spilleren er i kastet), skinnen midt-kutter til 16 tegn («ALEXANDER … BITCH») — start + slutt beholdes, kortet vokser aldri."/>
      <SRow k="Ikke vist (besluttet)" v="Kumulativ dart-count, legs/sets (TopBar), motstander-AVG (player sheet)."/>
    </div>
    <div style={{padding:'11px 14px',background:'#eae6f5',border:'1px solid rgba(90,70,150,0.28)'}}>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,color:'#3a2f5a',lineHeight:1.55}}><b>Hvorfor B (valgt over A/C):</b> den vertikale skinnen gir plass til alle 6 spillere med lesbare tall OG frigjør venstre kolonne til store LAST/AVG/CHECKOUT-verdier — lesbart fra oche-avstand (~1m). Aktiv spiller står i skinnen med accent-markering, så egen rang er alltid synlig. Skinnen er formen de fire andre modene arver.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:11,fontWeight:800,color:'#8a8378',textTransform:'uppercase',letterSpacing:0.5,marginBottom:4}}>Stress-states på artboardet</div>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,color:'#5a544a',lineHeight:1.6}}>1. Første dart (alt placeholder, alle 501 — ingen 👑/delta) · 2. Lengste navn &gt;16 tegn (10px-kurven) · 3. Seks spillere uten checkout · 4. Seks spillere + checkout = max-staten som definerer 272px.</div>
    </div>
    <div style={{marginTop:'auto',padding:'12px 14px',background:'#dcefe1',border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,lineHeight:1.55,color:'#2a4a36'}}><b>Implementasjon eier:</b> checkout-beregning, «to win»-matte, all oppførsel, <b>DossedartX01ActiveCard</b>-omskriving og fixed-height-regresjonstesten som pinner 272px. Tokens only · Press Start 2P / VT323 · no border-radius · English strings.</div>
    </div>
  </div>
);

// ── canvas ──────────────────────────────────────────────────────
const stTied=P4.map(p=>({...p,remaining:501}));
const stLong=[{handle:'ALE',name:'Alexander the boss bitch',accent:MAGENTA,remaining:97,active:true},{...P6[0],active:false},P6[3],P6[5]];
const stSixNoCk=[{...P6[0],remaining:220},{...P6[1],remaining:289},{...P6[2],remaining:347},{...P6[3],remaining:318},{...P6[4],remaining:364},{...P6[5],remaining:401}];
const X01OverviewRound=()=>(
  <React.Fragment>
    <DCSection id="xo-today" title="Dagens X01-overview" subtitle="Som den skipper i 1.16.0+41: NOW THROWING-badge, gradient-fill, låst accent-logikk, INGEN motstandere synlig — og checkout-stripen som dukker opp og forsvinner. Det er den som gir 232→272px-hoppet: brettkanten flytter seg mellom darts.">
      <DCArtboard id="today-ck" label="I dag · checkout synlig (max)" width={W} height={460}><TodayFrame p={{handle:'JON',name:'Jonas',accent:CYAN,remaining:170,dartIdx:2,last:'T20 · T20 · —',lastSum:120}} checkout="T20 › T20 › D-BULL"/></DCArtboard>
      <DCArtboard id="today-nock" label="I dag · ingen checkout — kortet krymper, brettet hopper opp" width={W} height={460}><TodayFrame p={{handle:'JON',name:'Jonas',accent:CYAN,remaining:347,dartIdx:1,last:'60 · — · —',lastSum:60}} jumpNote="◀ BOARD EDGE JUMPS UP HERE"/></DCArtboard>
    </DCSection>
    <DCSection id="xo-props" title="Tre forslag — alle i 272px-budsjettet, vist i max-staten (6 spillere + checkout)" subtitle="Felles: surface-fill, 3px per-spiller-accent-border (Live = lime), 14px glow, ingen badge, header med foto-avatar + navnkurve + 9px pips, REMAINING 60px, alltid-rendret checkout. Forskjellen er hvor standings bor. B er VALGT: oche-lesbare LAST/AVG/CHECKOUT + aktiv spiller synlig i skinnen.">
      <DCArtboard id="prop-a" label="A · footer-strip i kortet" width={W} height={460}><ZoneFrame><CardA s={MAX_STATE}/></ZoneFrame></DCArtboard>
      <DCArtboard id="prop-b" label="B · standings-skinne til høyre ✓ VALGT" width={W} height={460}><ZoneFrame><CardB s={MAX_STATE}/></ZoneFrame></DCArtboard>
      <DCArtboard id="prop-c" label="C · slankt kort + frittstående strip" width={W} height={460}><ZoneFrame><CardC s={MAX_STATE}/></ZoneFrame></DCArtboard>
    </DCSection>
    <DCSection id="xo-stress" title="Stress-states — forslag B (valgt)" subtitle="Alle fire statene fra brief-en, i samme 272px uten vekst: placeholders dimmer, ingenting kollapser.">
      <DCArtboard id="st-1" label="1 · Første dart — alt placeholder, alle på 501" width={W} height={460}><ZoneFrame><CardB s={{players:stTied,dartIdx:0,last:null,lastSum:null,avg:null,checkout:null}}/></ZoneFrame></DCArtboard>
      <DCArtboard id="st-2" label="2 · Lengste navn (24 tegn → 10px-kurven + ellipsis)" width={W} height={460}><ZoneFrame><CardB s={{players:stLong,dartIdx:1,last:'T19 · — · —',lastSum:57,avg:'44.1',hit:'48%',checkout:'T20 5 D16'}}/></ZoneFrame></DCArtboard>
      <DCArtboard id="st-3" label="3 · Seks spillere · ingen checkout (dimmet)" width={W} height={460}><ZoneFrame><CardB s={{players:stSixNoCk,dartIdx:2,last:'20 · 19 · —',lastSum:39,avg:'41.7',hit:'55%',checkout:null}}/></ZoneFrame></DCArtboard>
      <DCArtboard id="st-4" label="4 · MAX — seks spillere + checkout (definerer 272px)" width={W} height={460}><ZoneFrame><CardB s={MAX_STATE}/></ZoneFrame></DCArtboard>
    </DCSection>
    <DCSection id="xo-full" title="Full cockpit — forslag B" subtitle="Hele rammen med max-staten: brettet får samme topp-kant i alle fem modes når de andre rundene lander.">
      <DCArtboard id="full-a" label="Cockpit · B · max state" width={W} height={H}><FullCockpit s={MAX_STATE}/></DCArtboard>
      <DCArtboard id="spec" label="Spec · fasit" width={720} height={H}><SpecCard/></DCArtboard>
    </DCSection>
  </React.Fragment>
);
window.X01OverviewRound=X01OverviewRound;
