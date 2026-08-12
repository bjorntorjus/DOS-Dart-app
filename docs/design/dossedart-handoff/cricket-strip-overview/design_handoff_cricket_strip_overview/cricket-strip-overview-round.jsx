// DOSSEDART — Cricket / strip-family overview (mode round 3 · 2026-07-22)
// Scope: the shared DossedartActiveStrip + Cricket's marks grid.
// Today's design first, then three proposals, stress states, sibling thumbnails, fasit.
const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', PURPLE='#B15CFF',
      BG='#0a0014', SURFACE='#1a0030', PHOSPHOR='#D9D2C2';
const INK='rgba(255,255,255,';
const PS='"Press Start 2P", monospace';
const VT='"VT323", monospace';
const W=820, H=1180, STRIP_ZONE=132, STRIP_CARD=110;
const TARGETS=['20','19','18','17','16','15','BULL'];
const nameSize=(n)=>n.length<=8?18:n.length<=12?15:n.length<=16?12:10;

// ── data — accents from the 5-accent cycle (rule 7) ─────────────
const mk=(name,handle,accent,points,marks,o={})=>({name,handle,accent,points,marks,...o});
const M=(a,b,c,d,e,f,g)=>({'20':a,'19':b,'18':c,'17':d,'16':e,'15':f,'BULL':g});
const P4=[
  mk('Jonas','JON',CYAN,62,M(3,3,2,1,0,1,0)),
  mk('Kari','KAR',MAGENTA,28,M(3,2,3,0,1,0,1),{active:true,dartIdx:1,last:'T18 · 18 · ✗',lastMarks:4}),
  mk('Per','PER',GREEN,0,M(1,2,1,2,0,0,0)),
  mk('Mia','MIA',PURPLE,41,M(2,0,1,3,2,0,0)),
];
const P6=[ // 6 players (fit case) + 20 closed by all + one far ahead
  mk('Jonas','JON',CYAN,118,M(3,3,3,2,1,3,1)),
  mk('Kari','KAR',MAGENTA,6,M(3,1,2,0,1,0,0),{active:true,dartIdx:2,last:'20 · 5 · ✗',lastMarks:1}),
  mk('Per','PER',GREEN,24,M(3,2,0,1,3,0,0)),
  mk('Mia','MIA',PURPLE,15,M(3,0,1,3,0,2,0)),
  mk('Tor','TOR',ORANGE,32,M(3,3,1,0,2,0,2)),
  mk('Andreas','AND',CYAN,0,M(3,1,0,2,0,1,0)),
];
const P3_FIRST=[ // first dart of the game
  mk('Jonas','JON',CYAN,0,M(0,0,0,0,0,0,0)),
  mk('Kari','KAR',MAGENTA,0,M(0,0,0,0,0,0,0),{active:true,dartIdx:0,last:null,lastMarks:null,firstDart:true}),
  mk('Per','PER',GREEN,0,M(0,0,0,0,0,0,0)),
];
const P4_LONG=[
  mk('Jonas','JON',CYAN,62,M(3,3,2,1,0,1,0)),
  mk('Alexander the boss bitch','ALE',MAGENTA,28,M(3,2,3,0,1,0,1),{active:true,dartIdx:1,last:'T18 · 18 · ✗',lastMarks:4}),
  mk('Per','PER',GREEN,0,M(1,2,1,2,0,0,0)),
  mk('Mia','MIA',PURPLE,41,M(2,0,1,3,2,0,0)),
];
const activeOf=(ps)=>ps.find(p=>p.active);
const leaderOf=(ps)=>{const mx=Math.max(...ps.map(p=>p.points));const tops=ps.filter(p=>p.points===mx);return{max:mx,leader:tops.length===1?tops[0]:null};};
const diffOf=(ps)=>{const a=activeOf(ps);const{max,leader}=leaderOf(ps);
  if(a.firstDart)return{text:'TIED',dim:true};
  if(a.points===max)return leader===a?{text:'YOU LEAD',lead:true}:{text:'TIED'};
  return{text:`▲ ${max-a.points} VS LEAD`};};

// ── grammar micro-parts (rule 4 — verbatim from X01/1UP) ────────
const PhotoAvatar=({size,handle,accent})=>(
  <div style={{width:size,height:size,flexShrink:0,border:`2px solid ${accent}`,position:'relative',boxShadow:`0 0 12px ${accent}55`,
               background:`repeating-linear-gradient(135deg, #1c0033 0, #1c0033 4px, #130024 4px, #130024 8px)`,
               display:'flex',alignItems:'center',justifyContent:'center'}}>
    <span style={{fontFamily:VT,fontSize:size*0.4,color:INK+'0.42)',letterSpacing:1}}>{handle}</span>
    {size>=40&&<span style={{position:'absolute',bottom:2,right:3,fontFamily:VT,fontSize:8,color:INK+'0.28)'}}>▨</span>}
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

// ── shared chrome ───────────────────────────────────────────────
const scan=`repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const TopBar=({title='CRICKET · STANDARD',rnd='RND 6'})=>(
  <div style={{padding:'13px 22px',background:'#000',borderBottom:`2px solid ${MAGENTA}`,display:'flex',alignItems:'center',gap:14,position:'relative',zIndex:6,flexShrink:0}}>
    <div style={{fontFamily:VT,fontSize:19,color:CYAN,letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1,textAlign:'center',fontFamily:PS,fontSize:12,color:YELLOW,letterSpacing:2,textShadow:`0 0 8px ${YELLOW}88`}}>{title}</div>
    <div style={{fontFamily:VT,fontSize:17,color:INK+'0.55)',letterSpacing:2}}>{rnd}</div>
  </div>
);
const ActionBar=()=>(
  <div style={{padding:'12px 16px 16px',background:'#000',borderTop:`2px solid ${YELLOW}`,display:'flex',gap:10,position:'relative',zIndex:6,flexShrink:0}}>
    <div style={{flex:1,padding:'15px 8px',border:`2px solid ${MAGENTA}`,fontFamily:PS,fontSize:12,color:'#fff',letterSpacing:1,textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:2,padding:'15px 8px',background:ORANGE,border:'2px solid #fff',fontFamily:PS,fontSize:12,color:BG,letterSpacing:2,textAlign:'center',boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:1,padding:'15px 8px',border:`2px solid ${CYAN}`,fontFamily:PS,fontSize:12,color:CYAN,letterSpacing:1,textAlign:'center'}}>⋯ MENU</div>
  </div>
);
const Frame=({children,h=H})=>(
  <div style={{width:W,height:h,background:BG,color:'#fff',fontFamily:PS,display:'flex',flexDirection:'column',overflow:'hidden',position:'relative'}}>
    <div style={{position:'absolute',inset:0,backgroundImage:scan,pointerEvents:'none',zIndex:5}}></div>
    {children}
  </div>
);
const Ruler=({label})=>(
  <div style={{position:'absolute',top:0,bottom:0,right:2,width:13,borderTop:`1px solid ${YELLOW}99`,borderBottom:`1px solid ${YELLOW}99`,borderRight:`1px solid ${YELLOW}99`,zIndex:7,pointerEvents:'none'}}>
    <span style={{position:'absolute',top:'50%',right:2,transform:'translateY(-50%)',writingMode:'vertical-rl',fontFamily:PS,fontSize:6,color:YELLOW,letterSpacing:1}}>{label}</span>
  </div>
);

// ── THE FAMILY STRIP (DossedartActiveStrip, restyled) ───────────
// Anatomy: [header rule 4] · [MODE SLOT] · [SCORE BLOCK w/ diff plate]
const SlotLabel=({children})=>(<div style={{fontFamily:PS,fontSize:7,color:INK+'0.45)',letterSpacing:1}}>{children}</div>);
const DiffPlate=({d})=>(
  <div style={{marginTop:6,padding:'4px 7px',border:`1px solid ${d.lead?YELLOW:YELLOW+'aa'}`,background:d.lead?`${YELLOW}14`:'transparent',opacity:d.dim?0.34:1,whiteSpace:'nowrap'}}>
    <span style={{fontFamily:PS,fontSize:8,color:YELLOW,letterSpacing:0.5,textShadow:d.dim?'none':`0 0 6px ${YELLOW}66`}}>{d.lead?'👑 YOU LEAD':d.text}</span>
  </div>
);
const ScoreBlock=({label,value,accent,d,small})=>(
  <div style={{borderLeft:`1px solid ${INK}0.12)`,paddingLeft:16,marginLeft:4,display:'flex',flexDirection:'column',alignItems:'flex-end',justifyContent:'center',flexShrink:0}}>
    <SlotLabel>{label}</SlotLabel>
    <div style={{fontFamily:PS,fontSize:small?22:30,color:accent,lineHeight:1,letterSpacing:-1,marginTop:5,textShadow:`0 0 12px ${accent}aa`}}>{value}</div>
    {d&&<DiffPlate d={d}/>}
  </div>
);
const StripHeader=({p})=>(
  <div style={{display:'flex',alignItems:'center',gap:13,flex:1,minWidth:0}}>
    <PhotoAvatar size={56} handle={p.handle} accent={p.accent}/>
    <div style={{flex:1,minWidth:0}}>
      <div style={{fontFamily:PS,fontSize:nameSize(p.name),color:'#fff',letterSpacing:1.5,lineHeight:1.2,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{p.name.toUpperCase()}</div>
      <div style={{marginTop:9}}><Pips accent={p.accent} n={p.dartIdx}/></div>
    </div>
  </div>
);
const stripFrame=(acc)=>({boxSizing:'border-box',height:STRIP_CARD,margin:'12px 14px 10px',padding:'10px 16px',
  background:SURFACE,border:`3px solid ${acc}`,boxShadow:`0 0 14px ${acc}66`,display:'flex',alignItems:'center',gap:14,position:'relative',zIndex:2});
// mode slot content — Cricket: last turn's marks (P3, always rendered)
const LastTurnSlot=({p,wide})=>(
  <div style={{borderLeft:`1px solid ${INK}0.12)`,paddingLeft:16,width:wide?300:212,flexShrink:0,opacity:p.last?1:0.34}}>
    <SlotLabel>LAST TURN</SlotLabel>
    <div style={{fontFamily:VT,fontSize:26,color:YELLOW,letterSpacing:1.5,lineHeight:1,marginTop:6,whiteSpace:'nowrap',textShadow:p.last?`0 0 8px ${YELLOW}55`:'none'}}>{p.last||'— · — · —'}</div>
    <div style={{fontFamily:VT,fontSize:14,color:INK+'0.5)',letterSpacing:1,marginTop:3}}>{p.last?`= ${p.lastMarks} MARKS`:'NO DARTS YET'}</div>
  </div>
);
const CricketStrip=({ps,slim,noDiff})=>{const p=activeOf(ps);return (
  <div style={{height:STRIP_ZONE,flexShrink:0,position:'relative'}}>
    <div style={stripFrame(p.accent)}>
      <StripHeader p={p}/>
      <LastTurnSlot p={p} wide={slim}/>
      {!slim&&<ScoreBlock label="POINTS" value={p.points} accent={p.accent} d={noDiff?null:diffOf(ps)}/>}
    </div>
    <Ruler label="STRIP · 132 PX"/>
  </div>
);};

// ── THE MARKS GRID (Cricket's primary element, rule 6) ──────────
const Glyph=({n,color,size=24})=>{
  if(n===0)return <span style={{fontFamily:VT,fontSize:16,color:INK+'0.18)'}}>·</span>;
  const g=n>=3?'⊗':n===2?'X':'/';
  return <span style={{fontFamily:PS,fontSize:n>=3?size+2:size,color,textShadow:`0 0 9px ${color}aa`,lineHeight:1}}>{g}</span>;
};
const HeadCell=({p,leader,showPts,showDiff,ps,border,bigPts})=>{
  const c=p.accent, isLead=leader===p;
  return (
    <div style={{padding:'7px 4px 6px',borderRight:border?`1px solid ${MAGENTA}33`:'none',display:'flex',flexDirection:'column',alignItems:'center',gap:3,background:p.active?`${c}14`:'transparent',position:'relative',minWidth:0}}>
      {p.active&&<div style={{position:'absolute',top:0,left:0,right:0,height:3,background:c,boxShadow:`0 0 8px ${c}`}}></div>}
      <PhotoAvatar size={26} handle={p.handle} accent={c}/>
      <div style={{display:'flex',alignItems:'center',gap:4}}>
        <span style={{fontFamily:PS,fontSize:8,color:p.active?'#fff':INK+'0.75)',letterSpacing:0.5}}>{p.handle}</span>
        {isLead&&<span style={{fontSize:10,lineHeight:1}}>👑</span>}
      </div>
      {showPts&&<div style={{fontFamily:bigPts?PS:VT,fontSize:bigPts?17:22,color:c,lineHeight:1,marginTop:bigPts?3:0,textShadow:`0 0 ${bigPts?9:6}px ${c}${bigPts?'aa':'66'}`}}>{p.points}</div>}
      {showDiff&&(()=>{const{max}=leaderOf(ps);const gap=max-p.points;
        return <div style={{fontFamily:PS,fontSize:6,color:YELLOW,letterSpacing:0.5,opacity:gap===0&&!isLead?0.5:1}}>{isLead?'LEAD':gap===0?'TIED':`▲${gap}`}</div>;})()}
    </div>
  );
};
const ActiveCell=({t,marks,accent,marksMode})=>{
  const c=accent, closed=marks>=3, isBull=t==='BULL';
  const subs=isBull?[{label:'BULL',m:1},{label:'D-BULL',m:2},{label:'—',off:true}]
                   :[{label:t,m:1},{label:`D${t}`,m:2},{label:`T${t}`,m:3}];
  const bg=closed?`${c}06`:`${c}10`;
  return (
    <div style={{borderRight:`1px solid ${MAGENTA}33`,background:bg,display:'flex',position:'relative',minWidth:0}}>
      {marksMode==='seg'&&!closed&&(
        <div style={{position:'absolute',bottom:0,left:0,right:0,display:'flex',gap:3,padding:'0 5px 5px',zIndex:1,pointerEvents:'none'}}>
          {[0,1,2].map(i=>(<div key={i} style={{flex:1,height:10,boxSizing:'border-box',background:i<marks?c:'rgba(0,0,0,0.4)',border:`2px solid ${i<marks?c:c+'66'}`,boxShadow:i<marks?`0 0 8px ${c}aa`:'none'}}/>))}
        </div>)}
      {marksMode==='col'&&!closed&&(
        <div style={{width:46,flexShrink:0,display:'flex',alignItems:'center',justifyContent:'center',background:`${c}0c`}}>
          <Glyph n={marks} color={c} size={20}/>
        </div>)}
      {marksMode==='pips'&&!closed&&(
        <div style={{position:'absolute',bottom:5,left:0,right:0,display:'flex',justifyContent:'center',gap:6,zIndex:1,pointerEvents:'none'}}>
          {[0,1,2].map(i=>(<div key={i} style={{width:9,height:9,background:i<marks?c:'transparent',border:`2px solid ${i<marks?c:c+'55'}`,boxShadow:i<marks?`0 0 6px ${c}aa`:'none'}}/>))}
        </div>)}
      {closed&&<div style={{position:'absolute',inset:0,display:'flex',alignItems:'center',justifyContent:'center',zIndex:1}}>
        <span style={{fontFamily:PS,fontSize:26,color:c,textShadow:`0 0 12px ${c}`,opacity:0.85}}>⊗</span></div>}
      {!closed&&subs.map(s=>{
        const willClose=!marksMode&&!s.off&&marks+s.m>=3;
        return (
          <div key={s.label} style={{flex:1,minWidth:0,borderLeft:`1px dashed ${c}55`,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',opacity:s.off?0.25:1,padding:'0 2px',position:'relative'}}>
            <span style={{fontFamily:PS,fontSize:s.label.length>3?11:14,color:s.off?INK+'0.35)':c,textShadow:s.off?'none':`0 0 8px ${c}aa`,textAlign:'center'}}>{s.label}</span>
            {willClose&&<span style={{position:'absolute',bottom:3,fontFamily:VT,fontSize:11,color:GREEN,letterSpacing:1,textShadow:`0 0 4px ${GREEN}aa`}}>CLOSES</span>}
          </div>
        );})}
    </div>
  );
};
const MarksGrid=({ps,showPts=true,showDiff=false,marksMode=null})=>{
  const {leader}=leaderOf(ps);
  const activeP=activeOf(ps);
  const cols=['52px',...ps.map(p=>p.active?'2.6fr':'1fr')].join(' ');
  return (
    <div style={{flex:1,minHeight:0,margin:'0 14px 12px',display:'flex',flexDirection:'column',border:`2px solid ${MAGENTA}55`,position:'relative',zIndex:2}}>
      <div style={{display:'grid',gridTemplateColumns:cols,background:`${MAGENTA}15`,borderBottom:`2px solid ${MAGENTA}55`}}>
        <div style={{display:'flex',alignItems:'center',justifyContent:'center',borderRight:`1px solid ${MAGENTA}33`,fontFamily:PS,fontSize:8,color:INK+'0.5)',letterSpacing:1}}>TGT</div>
        {ps.map((p,i)=>(<HeadCell key={i} p={p} leader={leader} showPts={showPts} showDiff={showDiff} ps={ps} border={i<ps.length-1} bigPts={!!marksMode}/>))}
      </div>
      {TARGETS.map((t,ti)=>{
        const closedByAll=ps.every(p=>p.marks[t]>=3);
        return (
          <div key={t} style={{flex:1,minHeight:0,display:'grid',gridTemplateColumns:cols,borderBottom:ti<TARGETS.length-1?`1px solid ${MAGENTA}22`:'none',opacity:closedByAll?0.3:1}}>
            <div style={{borderRight:`1px solid ${MAGENTA}33`,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:2}}>
              <span style={{fontFamily:PS,fontSize:t==='BULL'?11:19,color:closedByAll?INK+'0.4)':YELLOW,textShadow:closedByAll?'none':`0 0 8px ${YELLOW}88`}}>{t}</span>
              {closedByAll
                ?<span style={{fontFamily:VT,fontSize:11,color:INK+'0.45)',letterSpacing:1}}>DEAD</span>
                :marksMode==='tgt'&&activeP&&<Glyph n={activeP.marks[t]} color={activeP.accent} size={13}/>}
            </div>
            {ps.map((p,i)=>p.active
              ?<ActiveCell key={i} t={t} marks={p.marks[t]} accent={p.accent} marksMode={marksMode}/>
              :<div key={i} style={{borderRight:i<ps.length-1?`1px solid ${MAGENTA}22`:'none',display:'flex',alignItems:'center',justifyContent:'center',minWidth:0}}>
                 <Glyph n={p.marks[t]} color={p.accent} size={ps.length>4?20:24}/>
               </div>)}
          </div>
        );})}
    </div>
  );
};
// zoom crop — 3 rows at 1.75x so the marks-variants are actually comparable
const ZGrid=({ps,marksMode,rows})=>{
  const {leader}=leaderOf(ps);
  const activeP=activeOf(ps);
  const cols=['52px',...ps.map(p=>p.active?'2.6fr':'1fr')].join(' ');
  return (
    <div style={{margin:'0 14px',display:'flex',flexDirection:'column',border:`2px solid ${MAGENTA}55`,position:'relative',zIndex:2}}>
      <div style={{display:'grid',gridTemplateColumns:cols,background:`${MAGENTA}15`,borderBottom:`2px solid ${MAGENTA}55`}}>
        <div style={{display:'flex',alignItems:'center',justifyContent:'center',borderRight:`1px solid ${MAGENTA}33`,fontFamily:PS,fontSize:8,color:INK+'0.5)',letterSpacing:1}}>TGT</div>
        {ps.map((p,i)=>(<HeadCell key={i} p={p} leader={leader} showPts ps={ps} border={i<ps.length-1} bigPts/>))}
      </div>
      {rows.map((t,ti)=>(
        <div key={t} style={{height:64,display:'grid',gridTemplateColumns:cols,borderBottom:ti<rows.length-1?`1px solid ${MAGENTA}22`:'none'}}>
          <div style={{borderRight:`1px solid ${MAGENTA}33`,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:2}}>
            <span style={{fontFamily:PS,fontSize:19,color:YELLOW,textShadow:`0 0 8px ${YELLOW}88`}}>{t}</span>
            {marksMode==='tgt'&&<Glyph n={activeP.marks[t]} color={activeP.accent} size={13}/>}
          </div>
          {ps.map((p,i)=>p.active
            ?<ActiveCell key={i} t={t} marks={p.marks[t]} accent={p.accent} marksMode={marksMode}/>
            :<div key={i} style={{borderRight:i<ps.length-1?`1px solid ${MAGENTA}22`:'none',display:'flex',alignItems:'center',justifyContent:'center',minWidth:0}}>
               <Glyph n={p.marks[t]} color={p.accent} size={22}/>
             </div>)}
        </div>))}
    </div>
  );
};
const ZoomCrop=({marksMode,note})=>(
  <div style={{width:W,height:560,background:BG,position:'relative',overflow:'hidden',fontFamily:PS,color:'#fff'}}>
    <div style={{position:'absolute',inset:0,backgroundImage:scan,pointerEvents:'none',zIndex:5}}></div>
    <div style={{padding:'12px 16px 0',fontFamily:VT,fontSize:16,color:INK+'0.5)',letterSpacing:2,position:'relative',zIndex:2}}>ZOOM · 175% — KARI (magenta) I KASTET · 20: 3 TREFF · 19: 2 · 18: {note}</div>
    <div style={{transform:'scale(1.75)',transformOrigin:'top left',width:W/1.75,marginTop:10}}>
      <ZGrid ps={P4Z} marksMode={marksMode} rows={['20','19','18']}/>
    </div>
  </div>
);
const P4Z=[
  mk('Jonas','JON',CYAN,62,M(3,3,2,1,0,1,0)),
  mk('Kari','KAR',MAGENTA,28,M(3,2,1,0,1,0,1),{active:true,dartIdx:1}),
  mk('Per','PER',GREEN,0,M(1,2,1,2,0,0,0)),
  mk('Mia','MIA',PURPLE,41,M(2,0,1,3,2,0,0)),
];

// C only — standings footer (rule 7 rail, horizontal)
const StandingsFooter=({ps})=>{
  const sorted=[...ps].sort((a,b)=>b.points-a.points);
  const {leader}=leaderOf(ps);
  return (
    <div style={{height:44,margin:'0 14px 12px',display:'flex',gap:6,position:'relative',zIndex:2,flexShrink:0}}>
      {sorted.map((p,i)=>(
        <div key={i} style={{flex:1,minWidth:0,display:'flex',alignItems:'center',gap:6,padding:'0 8px',border:`1px solid ${p.active?p.accent:INK+'0.14)'}`,background:p.active?`${p.accent}14`:'rgba(0,0,0,0.2)',opacity:p.active?1:0.78}}>
          <span style={{fontFamily:PS,fontSize:8,color:leader===p?YELLOW:INK+'0.35)',flexShrink:0}}>{i+1}</span>
          <span style={{width:7,height:7,background:p.accent,boxShadow:`0 0 5px ${p.accent}`,flexShrink:0}}/>
          <span style={{fontFamily:PS,fontSize:8,color:'#fff',letterSpacing:0.5,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{p.handle}</span>
          {leader===p&&<span style={{fontSize:10,flexShrink:0}}>👑</span>}
          <span style={{marginLeft:'auto',fontFamily:VT,fontSize:20,color:p.accent,lineHeight:1,textShadow:`0 0 6px ${p.accent}66`,flexShrink:0}}>{p.points}</span>
        </div>
      ))}
    </div>
  );
};

// ── full cockpits per proposal ──────────────────────────────────
const CockpitA=({ps,rnd})=>(<Frame><TopBar rnd={rnd}/><CricketStrip ps={ps}/><MarksGrid ps={ps} showPts/><ActionBar/></Frame>);
const CockpitAPlus=({ps,rnd,marksMode='seg'})=>(<Frame><TopBar rnd={rnd}/><CricketStrip ps={ps} noDiff/><MarksGrid ps={ps} showPts marksMode={marksMode}/><ActionBar/></Frame>);
const CockpitB=({ps,rnd})=>(<Frame><TopBar rnd={rnd}/><CricketStrip ps={ps} slim/><MarksGrid ps={ps} showPts showDiff/><ActionBar/></Frame>);
const CockpitC=({ps,rnd})=>(<Frame><TopBar rnd={rnd}/><CricketStrip ps={ps}/><MarksGrid ps={ps} showPts={false}/><StandingsFooter ps={ps}/><ActionBar/></Frame>);

// ── sibling strips (same component, different mode slot) ────────
const ModeSlot=({label,value,sub,subColor,accent})=>(
  <div style={{borderLeft:`1px solid ${INK}0.12)`,paddingLeft:16,width:232,flexShrink:0}}>
    <SlotLabel>{label}</SlotLabel>
    <div style={{fontFamily:PS,fontSize:30,color:accent,lineHeight:1,letterSpacing:-1,marginTop:6,textShadow:`0 0 12px ${accent}aa`,whiteSpace:'nowrap'}}>{value}</div>
    <div style={{fontFamily:VT,fontSize:14,color:subColor||INK+'0.5)',letterSpacing:1,marginTop:4,whiteSpace:'nowrap'}}>{sub}</div>
  </div>
);
const SiblingFrame=({title,rnd,p,slot,score})=>(
  <Frame h={420}>
    <TopBar title={title} rnd={rnd}/>
    <div style={{height:STRIP_ZONE,flexShrink:0,position:'relative'}}>
      <div style={stripFrame(p.accent)}>
        <StripHeader p={p}/>
        {slot}
        {score}
      </div>
      <Ruler label="STRIP · 132 PX"/>
    </div>
    <div style={{flex:1,margin:'2px 14px 14px',border:`2px dashed ${INK}0.18)`,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:8}}>
      <span style={{fontFamily:PS,fontSize:10,color:INK+'0.38)',letterSpacing:2}}>▦ INPUT STRIPS / KEYS</span>
      <span style={{fontFamily:VT,fontSize:16,color:INK+'0.3)',letterSpacing:1}}>approved chrome · out of scope</span>
    </div>
  </Frame>
);
const ATC_P={name:'Kari',handle:'KAR',accent:MAGENTA,dartIdx:1};
const SHA_P={name:'Per',handle:'PER',accent:GREEN,dartIdx:0};
const SPL_P={name:'Mia',handle:'MIA',accent:PURPLE,dartIdx:2};

// ── TODAY — faithful to the locked palette-round Cricket ────────
const tColor=(p)=>p.active?YELLOW:PHOSPHOR;
const TodayStrip=({ps})=>{const p=activeOf(ps),c=YELLOW;return (
  <div style={{padding:'12px 22px',display:'flex',alignItems:'center',gap:14,background:`linear-gradient(90deg, ${c}1c 0%, transparent 100%)`,borderBottom:`2px solid ${c}`,boxShadow:`0 0 18px ${c}44`,position:'relative',zIndex:2,flexShrink:0}}>
    <div style={{width:48,height:48,background:BG,border:`3px solid ${c}`,display:'flex',alignItems:'center',justifyContent:'center',fontFamily:PS,fontSize:13,color:c,textShadow:`0 0 8px ${c}aa`,flexShrink:0}}>{p.handle}</div>
    <div style={{flex:1,minWidth:0}}>
      <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:4}}>
        <span style={{color:c,fontFamily:PS,fontSize:11,letterSpacing:1.5,textShadow:`0 0 6px ${c}aa`,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>▶ {p.name.toUpperCase()}</span>
        <span style={{fontFamily:VT,fontSize:13,color:INK+'0.5)',letterSpacing:2,flexShrink:0}}>DART {p.dartIdx+1} / 3</span>
      </div>
      <div style={{display:'flex',alignItems:'center',gap:10}}>
        <div style={{display:'flex',gap:6}}>{[0,1,2].map(i=>(<div key={i} style={{width:12,height:12,borderRadius:'50%',background:i<p.dartIdx?c:'transparent',border:`2px solid ${c}`}}/>))}</div>
        <div style={{fontFamily:VT,fontSize:14,color:INK+'0.7)',letterSpacing:2}}>LAST · <span style={{color:c,fontFamily:PS,fontSize:10}}>{p.last||'—'}</span></div>
      </div>
    </div>
    <div style={{textAlign:'right'}}>
      <div style={{fontFamily:VT,fontSize:12,color:INK+'0.45)',letterSpacing:2}}>POINTS</div>
      <div style={{fontFamily:PS,fontSize:36,color:c,lineHeight:1,textShadow:`0 0 14px ${c}aa`,marginTop:2}}>{p.points}</div>
    </div>
  </div>
);};
const TodayGrid=({ps})=>{
  const cols=['52px',...ps.map(p=>p.active?'2.6fr':'1fr')].join(' ');
  return (
    <div style={{flex:1,minHeight:0,margin:'12px 16px',display:'flex',flexDirection:'column',border:`2px solid ${MAGENTA}55`,position:'relative',zIndex:2}}>
      <div style={{display:'grid',gridTemplateColumns:cols,background:`${MAGENTA}15`,borderBottom:`2px solid ${MAGENTA}55`}}>
        <div style={{display:'flex',alignItems:'center',justifyContent:'center',borderRight:`1px solid ${MAGENTA}33`,fontFamily:PS,fontSize:8,color:INK+'0.5)',letterSpacing:1}}>TGT</div>
        {ps.map((p,i)=>{const c=tColor(p);return (
          <div key={i} style={{padding:'8px 4px',borderRight:i<ps.length-1?`1px solid ${MAGENTA}33`:'none',display:'flex',flexDirection:'column',alignItems:'center',gap:2,background:p.active?`${c}1c`:'transparent',position:'relative',minWidth:0}}>
            {p.active&&<div style={{position:'absolute',top:0,left:0,right:0,height:3,background:c,boxShadow:`0 0 8px ${c}`}}></div>}
            <span style={{fontFamily:PS,fontSize:p.active?12:10,color:c,letterSpacing:1,textShadow:`0 0 6px ${c}aa`}}>{p.handle}{p.active?' ▶':''}</span>
            <span style={{fontFamily:PS,fontSize:p.active?20:15,color:c,textShadow:`0 0 8px ${c}aa`}}>{p.points}</span>
            <span style={{fontFamily:VT,fontSize:11,color:INK+'0.4)',letterSpacing:1}}>pts</span>
          </div>
        );})}
      </div>
      {TARGETS.map((t,ti)=>{
        const closedByAll=ps.every(p=>p.marks[t]>=3);
        return (
          <div key={t} style={{flex:1,minHeight:0,display:'grid',gridTemplateColumns:cols,borderBottom:ti<TARGETS.length-1?`1px solid ${MAGENTA}22`:'none',opacity:closedByAll?0.3:1}}>
            <div style={{borderRight:`1px solid ${MAGENTA}33`,display:'flex',alignItems:'center',justifyContent:'center',fontFamily:PS,fontSize:t==='BULL'?11:19,color:closedByAll?INK+'0.4)':YELLOW,textShadow:closedByAll?'none':`0 0 8px ${YELLOW}88`}}>{t}</div>
            {ps.map((p,i)=>p.active
              ?<ActiveCell key={i} t={t} marks={p.marks[t]} accent={YELLOW}/>
              :<div key={i} style={{borderRight:i<ps.length-1?`1px solid ${MAGENTA}22`:'none',display:'flex',alignItems:'center',justifyContent:'center',minWidth:0}}>
                 <Glyph n={p.marks[t]} color={PHOSPHOR} size={ps.length>4?20:24}/>
               </div>)}
          </div>
        );})}
    </div>
  );
};
const TodayCockpit=({ps,rnd})=>(<Frame><TopBar rnd={rnd}/><TodayStrip ps={ps}/><TodayGrid ps={ps}/><ActionBar/></Frame>);

// ── spec / fasit ────────────────────────────────────────────────
const SRow=({k,v})=>(
  <div style={{display:'flex',gap:12,padding:'7px 0',borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{width:158,flexShrink:0,fontFamily:'"Inter",sans-serif',fontSize:12,fontWeight:800,color:'#2a251f'}}>{k}</div>
    <div style={{flex:1,fontFamily:'"Inter",sans-serif',fontSize:12,lineHeight:1.45,color:'#5a544a'}}>{v}</div>
  </div>
);
const SpecCard=()=>(
  <div style={{boxSizing:'border-box',width:720,height:H,background:'#fffdf6',border:'1.5px solid rgba(0,0,0,0.14)',padding:'30px 34px',fontFamily:'"Inter",system-ui,sans-serif',display:'flex',flexDirection:'column',gap:13,overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono",monospace',fontSize:11,letterSpacing:2,color:'#c96442',textTransform:'uppercase',fontWeight:600,marginBottom:6}}>Cricket / strip-family · mode round 3 · fasit</div>
      <div style={{fontFamily:'"Archivo","Inter",sans-serif',fontSize:25,fontWeight:900,letterSpacing:-0.5,color:'#2a251f',lineHeight:1.1}}>Forslag A+ — score i stripen, egne marks synlig i aktiv kolonne (valgt)</div>
    </div>
    <div style={{padding:'12px 14px',background:'#2a251f'}}>
      <div style={{fontFamily:'"JetBrains Mono",monospace',fontSize:13,fontWeight:700,color:'#C6FF3C',lineHeight:1.5}}>FAMILY STRIP: h=132 px @ 820×1180 — identisk i Cricket · ATC · Shanghai · Splitscore</div>
    </div>
    <div>
      <SRow k="Sone → strip" v="Kort 110px fast + marger 14/12/14/10. Aldri vekst (regel 2): LAST TURN er alltid rendret, dimmet 0.34 uten innhold (første dart)."/>
      <SRow k="Strip-anatomi" v={<span><b>[Header regel 4]</b> avatar 56px foto + navnkurve 18/15/12/10 + 9px pips + DART n/3 · <b>[MODE SLOT]</b> modusens data · <b>[SCORE-BLOKK]</b> tall PS-30 i accent (+ diff-plate der modusen trenger den). Én komponent i kode — søsknene bytter bare slot- og blokk-innhold.</span>}/>
      <SRow k="Kort-ramme (regel 5)" v="Surface #1A0030 · 3px border i spillerens accent (5-accent-syklusen, regel 7) · 14px glow. Gradient + ▶-prefiks fra dagens strip utgår."/>
      <SRow k="Cricket-slots" v={<span>MODE SLOT = <b>LAST TURN</b> «T18 · 18 · ✗ = 4 MARKS» (P3, gul VT-26) · SCORE-BLOKK = <b>POINTS</b> PS-30. Diff-platen (▲ n VS LEAD) er <b>besluttet UT</b> for Cricket — 👑 i grid-headeren bærer lederen. PS-30, ikke 60: grid-et er kortets primærelement (regel 6).</span>}/>
      <SRow k="Marks-grid" v={<span>Chrome-ramme (magenta hairlines) — stripen er kortet, grid-et er standings. Header-celle: 26px avatar + handle + points <b>PS-17 m/ glow</b> i spillerens accent, 👑 på unik leder. Marks-glyfer / X ⊗ i accent. Aktiv kolonne 2.6fr: accent-bakgrunn + topplinje, S/D/T-tapceller (approved input) der <b>cellen selv viser egne marks: tredelt SEGMENT-måler i bunnen, ett fylt segment per treff</b> (VALGT over PIPS/TGT-GLYF). CLOSES-hintet utgår.</span>}/>
      <SRow k="Grid-states" v="Closed-by-all: raden dim 0.3 + DEAD-tag under målet. Lukket for aktiv: celle låses, stor ⊗ i accent. Første dart: LAST TURN dimmet, ingen 👑. Alltid 7 rader — grid-et endrer aldri høyde (regel 2)."/>
      <SRow k="Stress: navn" v="Navnkurven bunner på 10px i stripen (>16 tegn). Grid-headerne bruker 3-tegns handle — immune mot lange navn. 6 spillere: opponent-kolonner ~103px, glyfer 20px — les-bart."/>
      <SRow k="Ikke vist (besluttet)" v="Kumulativ dart-count, MPR/stats (post-game/player sheet)."/>
    </div>
    <div style={{padding:'11px 14px',background:'#eae6f5',border:'1px solid rgba(90,70,150,0.28)'}}>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,color:'#3a2f5a',lineHeight:1.55}}><b>Hvorfor A+ (over B/C):</b> B (alt i grid-headerne) gjør stripen tom for søsknene — ATC/Shanghai/Splitscore trenger score-blokken, så arven ryker. C (standings-footer) dupliserer identitetsraden og stjeler 44px fra grid-et — som er primærelementet. A+ er A KISS-justert etter brukerrundene: diff-platen ut, egne marks integrert i tapcellene (ingen geometri som kommer/går), motstander-points opp i størrelse.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:11,fontWeight:800,color:'#8a8378',textTransform:'uppercase',letterSpacing:0.5,marginBottom:4}}>Stress-states på artboardet</div>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,color:'#5a544a',lineHeight:1.6}}>1. Første dart (LAST TURN dimmet, ingen 👑) · 2. Seks spillere + 20 closed-by-all + leder langt foran · 3. Lengste navn 24 tegn (10px-kurve i strip, handle i grid).</div>
    </div>
    <div style={{marginTop:'auto',padding:'12px 14px',background:'#dcefe1',border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,lineHeight:1.55,color:'#2a4a36'}}><b>Implementasjon eier:</b> diff-matten (snur i Cutthroat: lavest leder), all scoring/regler, <b>DossedartActiveStrip</b> + grid-omskriving, og fixed-height-regresjonstesten som pinner 132px i alle fire strip-modes. Tokens only · Press Start 2P / VT323 · no border-radius · English strings.</div>
    </div>
  </div>
);

// ── canvas ──────────────────────────────────────────────────────
const CricketStripOverviewRound=()=>(
  <React.Fragment>
    <DCSection id="cs-today" title="Dagens Cricket (låst i palett-runden)" subtitle="Som den skipper: mono hvit-fosfor (ingen per-spiller-accents), 48px handle-avatar med ▶-prefiks, POINTS 36px men INGEN diff mot leder, ingen leder-markering i grid-et. Ved 6 spillere klemmes opponent-kolonnene og alt renderer i samme fosfor-tone — hvem som leder er umulig å se fra oche.">
      <DCArtboard id="today-4" label="I dag · 4 spillere" width={W} height={H}><TodayCockpit ps={P4}/></DCArtboard>
      <DCArtboard id="today-6" label="I dag · 6 spillere — mono-fosfor, ingen leder, ingen diff" width={W} height={H}><TodayCockpit ps={P6} rnd="RND 9"/></DCArtboard>
    </DCSection>
    <DCSection id="cs-chosen" title="Valgt retning — A+" subtitle="Score i stripen (kun POINTS — diff-platen er ute), points per spiller i grid-headerne (PS-17 m/ glow, 👑 på leder), per-spiller-accents på marks-glyfene, og egne treff som tredelt segment-måler i tapcellene. B (slank strip) og C (standings-footer) er forkastet i runden.">
      <DCArtboard id="chosen" label="A+ · 4 spillere · SEGMENTER ★" width={W} height={H}><CockpitAPlus ps={P4}/></DCArtboard>
    </DCSection>
    <DCSection id="cs-zoom" title="Zoom — egne treff i aktiv kolonne, tre varianter" subtitle="Samme tre rader (20/19/18) i 175% så forskjellen faktisk synes. Kari (magenta) er i kastet med 3/2/1 treff: SEGMENTER — tredelt måler i bunnen av cellen, ett fylt segment per treff (★ anbefalt) · PIPS — tre små kvadrat-pips · TGT-GLYF — samme / X-språk som motstanderne, men i TGT-kolonnen. Motstanderne beholder / X ⊗ i egne accents i alle varianter.">
      <DCArtboard id="zoom-seg" label="SEGMENTER — ███ / ██· / █·· ★ ANBEFALT" width={W} height={560}><ZoomCrop marksMode="seg" note="1 TREFF"/></DCArtboard>
      <DCArtboard id="zoom-pips" label="PIPS — tre små mark-pips nederst" width={W} height={560}><ZoomCrop marksMode="pips" note="1 TREFF"/></DCArtboard>
      <DCArtboard id="zoom-tgt" label="TGT-GLYF — / X i mål-kolonnen" width={W} height={560}><ZoomCrop marksMode="tgt" note="1 TREFF"/></DCArtboard>
    </DCSection>
    <DCSection id="cs-stress" title="Stress-states — A+ (valgt)" subtitle="Alle i samme 132px strip + 7-raders grid uten vekst: LAST TURN dimmer på første dart, closed-by-all dimmer raden med DEAD-tag, 6 spillere får 20px-glyfer, langt navn treffer 10px-kurven i stripen mens grid-et kjører 3-tegns handles.">
      <DCArtboard id="st-1" label="1 · Første dart i spillet — placeholders dimmet, ingen 👑" width={W} height={H}><CockpitAPlus ps={P3_FIRST} rnd="RND 1"/></DCArtboard>
      <DCArtboard id="st-2" label="2 · Seks spillere · 20 closed-by-all · leder langt foran" width={W} height={H}><CockpitAPlus ps={P6} rnd="RND 9"/></DCArtboard>
      <DCArtboard id="st-3" label="3 · Lengste navn (24 tegn → 10px-kurve, grid immunt)" width={W} height={H}><CockpitAPlus ps={P4_LONG}/></DCArtboard>
    </DCSection>
    <DCSection id="cs-sibs" title="Søsknene arver stripen gratis" subtitle="Samme DossedartActiveStrip, samme 132px: header + score-blokk uendret, bare MODE SLOT bytter innhold. ATC/Shanghai/Splitscore har ikke noe grid — deres primærtall (regel 6) bor i slotten. Input-sonene under er approved chrome.">
      <DCArtboard id="sib-atc" label="ATC · target i slotten, progress + behind-plate" width={W} height={420}>
        <SiblingFrame title="AROUND THE CLOCK" rnd="RND 4" p={ATC_P}
          slot={<ModeSlot label="TARGET" value="7" sub="THEN 8 › 9 › 10" accent={ATC_P.accent}/>}
          score={<ScoreBlock label="PROGRESS" value="6/21" accent={ATC_P.accent} small d={{text:'▲ 5 BEHIND'}}/>}/>
      </DCArtboard>
      <DCArtboard id="sib-sha" label="Shanghai · runde/target i slotten, points + diff" width={W} height={420}>
        <SiblingFrame title="SHANGHAI" rnd="RND 4/7" p={SHA_P}
          slot={<ModeSlot label="ROUND 4 · TARGET" value="4" sub="S4 · D8 · T12 — SHANGHAI WINS" accent={SHA_P.accent}/>}
          score={<ScoreBlock label="POINTS" value="86" accent={SHA_P.accent} small d={{text:'▲ 12 VS LEAD'}}/>}/>
      </DCArtboard>
      <DCArtboard id="sib-spl" label="Splitscore · target + risiko i slotten" width={W} height={420}>
        <SiblingFrame title="SPLITSCORE" rnd="RND 5/9" p={SPL_P}
          slot={<ModeSlot label="TARGET" value="D19" sub="MISS HALVES 240 › 120" subColor={RED} accent={SPL_P.accent}/>}
          score={<ScoreBlock label="POINTS" value="240" accent={SPL_P.accent} small d={{text:'YOU LEAD',lead:true}}/>}/>
      </DCArtboard>
    </DCSection>
    <DCSection id="cs-spec" title="Fasit" subtitle="Spec-kortet implementasjonen bygger og regresjonstester mot.">
      <DCArtboard id="spec" label="Spec · fasit" width={720} height={H}><SpecCard/></DCArtboard>
    </DCSection>
  </React.Fragment>
);
window.CricketStripOverviewRound=CricketStripOverviewRound;
