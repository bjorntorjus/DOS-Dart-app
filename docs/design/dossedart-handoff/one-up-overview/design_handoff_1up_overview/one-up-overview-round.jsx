// DOSSEDART — 1UP overview round (mode round 2/5 · 2026-07-22)
// Restyle onto the approved X01 skeleton (proposal B): 272px zone, 250px card,
// same frame/header/rail. The one design question: what carries SAFE/CAN'T-BEAT
// now that the frame border = player identity. Three proposals below.
const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', LIME='#C6FF3C', PURPLE='#7B3FFF',
      BG='#0a0014', SURFACE='#1a0030';
const INK='rgba(255,255,255,';
const PS='"Press Start 2P", monospace';
const VT='"VT323", monospace';
const W=820, H=1180, ZONE=272;
const nameSize=(n)=>n.length<=8?18:n.length<=12?15:n.length<=16?12:10;
const midTrunc=(n,max)=>n.length<=max?n:n.slice(0,Math.ceil((max-1)*0.6))+'…'+n.slice(n.length-Math.floor((max-1)*0.4));

// ── demo data — accents strictly from the 5-accent cycle (rule 7) ─
const mkP=(name,handle,accent,lives,o={})=>({name,handle,accent,lives,maxLives:3,...o});
const B4=(kar)=>[mkP('Jonas','JON',CYAN,3),{...mkP('Kari','KAR',MAGENTA,2),active:true,...kar},mkP('Per','PER',GREEN,3),mkP('Mia','MIA',PURPLE,1)];
const ST={
  free:{players:B4({lives:3}).map(p=>({...p,lives:3})),dartIdx:0,turnTotal:0,target:null,mode:'free',variant:'BEAT THE LAST',targetBy:null,round:1},
  need:{players:B4(),dartIdx:1,turnTotal:42,target:87,mode:'need',variant:'BEAT THE LAST',targetBy:'JONAS',round:3},
  safe:{players:B4(),dartIdx:2,turnTotal:92,target:87,mode:'safe',variant:'BEAT THE LAST',targetBy:'JONAS',round:3},
  cant:{players:B4(),dartIdx:2,turnTotal:30,target:145,mode:'cant',variant:'BEAT THE LAST',targetBy:'JONAS',round:5},
  lastlife:{players:[mkP('Jonas','JON',CYAN,2),{...mkP('Kari','KAR',MAGENTA,1),active:true},mkP('Per','PER',GREEN,3),{...mkP('Mia','MIA',PURPLE,0),dead:true}],dartIdx:2,turnTotal:71,target:118,mode:'need',variant:'BEAT THE LAST',targetBy:'PER',round:6},
  survivor:{players:[mkP('Jonas','JON',CYAN,3),{...mkP('Kari','KAR',MAGENTA,2),active:true},{...mkP('Per','PER',GREEN,3),roundOut:true},mkP('Mia','MIA',PURPLE,1),mkP('Tor','TOR',ORANGE,3),{...mkP('Andreas','AND',CYAN,2),roundOut:true}],dartIdx:1,turnTotal:57,target:95,mode:'need',variant:'SURVIVOR · RND 4',targetBy:'TOR',round:4},
  longname:{players:[mkP('Jonas','JON',CYAN,3),{...mkP('Alexander the boss bitch','ALE',MAGENTA,2),active:true},mkP('Per','PER',GREEN,3),mkP('Mia','MIA',PURPLE,1)],dartIdx:1,turnTotal:26,target:104,mode:'need',variant:'BEAT THE LAST',targetBy:'JONAS',round:2},
  fullSafe:{players:[mkP('Jonas','JON',CYAN,3),{...mkP('Kari','KAR',MAGENTA,2),active:true},{...mkP('Per','PER',GREEN,3),roundOut:true},mkP('Mia','MIA',PURPLE,1),mkP('Tor','TOR',ORANGE,3),{...mkP('Andreas','AND',CYAN,2),roundOut:true}],dartIdx:2,turnTotal:101,target:95,mode:'safe',variant:'SURVIVOR · RND 4',targetBy:'TOR',round:4},
};
const activeOf=(s)=>s.players.find(p=>p.active);
const aliveOf=(s)=>s.players.filter(p=>!p.dead).length;

// ── grammar micro-parts (rule 4 — verbatim from X01) ─────────────
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
const Hearts=({lives,max,accent,size=13})=>(
  <div style={{display:'flex',gap:size>16?5:3,alignItems:'center'}}>
    {Array.from({length:max}).map((_,i)=>{const live=i<lives;const col=(live&&lives===1)?RED:accent;
      return <span key={i} style={{fontFamily:VT,fontSize:size,lineHeight:1,color:live?col:INK+'0.18)',textShadow:live?`0 0 6px ${col}`:'none'}}>{live?'♥':'♡'}</span>;})}
  </div>
);
// primary slot (rule 6): BEAT <target> 60px — or the SET THE TARGET treatment
const Primary=({s,prop})=>{
  const p=activeOf(s);
  if(s.mode==='free')return (
    <div style={{textAlign:'right'}}>
      <div style={{fontFamily:PS,fontSize:8,color:INK+'0.55)',letterSpacing:1.5}}>FREE THROW</div>
      <div style={{fontFamily:PS,fontSize:22,color:LIME,lineHeight:1.3,letterSpacing:0.5,marginTop:8,textShadow:`0 0 14px ${LIME}aa`}}>SET THE<br/>TARGET</div>
    </div>);
  const col=prop==='C'?(s.mode==='safe'?GREEN:s.mode==='cant'?RED:p.accent):p.accent;
  return (
    <div style={{textAlign:'right'}}>
      <div style={{fontFamily:PS,fontSize:8,color:prop==='C'&&s.mode==='cant'?RED:INK+'0.55)',letterSpacing:1.5}}>BEAT</div>
      <div style={{fontFamily:PS,fontSize:60,color:col,lineHeight:1,letterSpacing:-2,marginTop:4,textShadow:`0 0 16px ${col}aa`}}>{s.target}</div>
    </div>);
};
const Header=({s,prop,helper})=>{const p=activeOf(s);return (
  <div style={{display:'flex',alignItems:'flex-start',gap:13}}>
    <PhotoAvatar size={56} handle={p.handle} accent={p.accent}/>
    <div style={{flex:1,minWidth:0,paddingTop:3}}>
      <div style={{display:'flex',alignItems:'center',gap:12,minWidth:0}}>
        <span style={{fontFamily:PS,fontSize:nameSize(p.name),color:'#fff',letterSpacing:1.5,lineHeight:1.2,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',minWidth:0}}>{p.name.toUpperCase()}</span>
        {helper&&<span style={{flexShrink:0,display:'flex',alignItems:'center',gap:8}}>
          <Hearts lives={p.lives} max={p.maxLives} accent={p.accent} size={17}/>
          {p.lives===1&&<span style={{fontFamily:PS,fontSize:7,color:RED,letterSpacing:1,border:`1px solid ${RED}`,padding:'2px 4px',textShadow:`0 0 8px ${RED}`}}>LAST LIFE</span>}
        </span>}
      </div>
      <div style={{marginTop:10}}><Pips accent={p.accent} n={s.dartIdx}/></div>
    </div>
    <Primary s={s} prop={prop}/>
  </div>);};
// status plate — ALWAYS rendered (rule 2). In proposal A it is THE state carrier.
const Plate=({s,prop,compact})=>{
  const need=s.target!=null?Math.max(0,s.target-s.turnTotal):null;
  const left=3-s.dartIdx, surv=s.variant.indexOf('SURVIVOR')===0;
  const filled=prop==='A';
  let border=INK+'0.14)', bg='rgba(255,255,255,0.04)', inner;
  if(s.mode==='free'){
    if(filled){border=`${LIME}88`;bg=`${LIME}0c`;}
    inner=<span style={{fontFamily:VT,fontSize:18,color:CYAN,letterSpacing:1}}>▸ YOUR 3-DART TOTAL {surv?'IS THE ROUND TARGET':'SETS THE BAR'}</span>;
  }else if(s.mode==='need'){
    inner=<React.Fragment>
      <span style={{fontFamily:PS,fontSize:12,color:YELLOW,letterSpacing:1,textShadow:`0 0 6px ${YELLOW}88`}}>NEED {need} MORE</span>
      {s.hit
        ?<span style={{display:'flex',alignItems:'center',gap:7}}><span style={{fontFamily:PS,fontSize:9,color:GREEN,lineHeight:1}}>▶</span><span style={{fontFamily:PS,fontSize:12,color:GREEN,letterSpacing:1,lineHeight:1,textShadow:`0 0 8px ${GREEN}66`}}>{s.hit}</span></span>
        :<span style={{fontFamily:VT,fontSize:16,color:INK+'0.45)'}}>· {left} DART{left!==1?'S':''} LEFT</span>}
    </React.Fragment>;
  }else if(s.mode==='safe'){
    if(filled){border=GREEN;bg=`${GREEN}1c`;}
    inner=<React.Fragment>
      <span style={{fontFamily:PS,fontSize:13,color:GREEN,letterSpacing:1,textShadow:`0 0 10px ${GREEN}`}}>SAFE ✓</span>
      <span style={{fontFamily:VT,fontSize:17,color:INK+'0.75)'}}>{surv?'ROUND SURVIVED':`NEW TARGET ${s.turnTotal}`}</span>
    </React.Fragment>;
  }else{
    if(filled){border=RED;bg=`${RED}1a`;}
    inner=<React.Fragment>
      <span style={{fontFamily:PS,fontSize:12,color:RED,letterSpacing:1,textShadow:`0 0 8px ${RED}`}}>CAN'T BEAT</span>
      <span style={{fontFamily:VT,fontSize:16,color:'#ff8fa6'}}>· MAX {60*left} LEFT</span>
    </React.Fragment>;
  }
  return <div style={{minHeight:compact?44:52,boxSizing:'border-box',display:'flex',alignItems:'center',gap:10,padding:compact?'6px 12px':'8px 12px',border:`2px solid ${border}`,background:bg,marginTop:compact?4:6}}>{inner}</div>;
};
const LRow=({label,children,dim,h=36,noLine})=>(
  <div style={{display:'flex',alignItems:'center',gap:12,padding:'3px 2px',borderTop:noLine?'none':`1px solid ${INK}0.1)`,minHeight:h,opacity:dim?0.34:1}}>
    <span style={{fontFamily:PS,fontSize:9,color:INK+'0.5)',letterSpacing:1,width:88,flexShrink:0}}>{label}</span>
    {children}
  </div>
);
const LeftCol=({s,prop})=>{const p=activeOf(s);return (
  <div style={{flex:1,minWidth:0,display:'flex',flexDirection:'column',justifyContent:'flex-end'}}>
    <LRow label="THIS TURN" dim={s.dartIdx===0} noLine>
      <span style={{fontFamily:VT,fontSize:28,color:p.accent,lineHeight:1,textShadow:`0 0 8px ${p.accent}66`}}>{s.turnTotal}</span>
    </LRow>
    <LRow label="LIVES">
      <Hearts lives={p.lives} max={p.maxLives} accent={p.accent} size={22}/>
      {p.lives===1&&<span style={{fontFamily:PS,fontSize:8,color:RED,letterSpacing:1,border:`1px solid ${RED}`,padding:'3px 5px',textShadow:`0 0 8px ${RED}`,boxShadow:`0 0 8px ${RED}44`}}>LAST LIFE</span>}
    </LRow>
    <Plate s={s} prop={prop}/>
  </div>);};
// A+ (PROPOSAL): KISS-varianten — lives ved navnet, THIS TURN viser total / mål,
// og HIT-forslaget står inne i status-platen etter NEED n MORE.
const LeftColH=({s,prop})=>{const p=activeOf(s);return (
  <div style={{flex:1,minWidth:0,display:'flex',flexDirection:'column',justifyContent:'space-between'}}>
    <LRow label="THIS TURN" dim={s.dartIdx===0} h={52} noLine>
      <span style={{fontFamily:VT,fontSize:38,color:p.accent,lineHeight:1,textShadow:`0 0 10px ${p.accent}66`}}>{s.turnTotal}</span>
      <span style={{fontFamily:VT,fontSize:28,color:INK+'0.35)',lineHeight:1}}>/ {s.target!=null?s.target:'—'}</span>
    </LRow>
    <Plate s={s} prop={prop}/>
  </div>);};
// rail — the X01 300px shape, poured with lives. Sort = THROW ORDER (design call).
const RailRow=({o,i})=>{const dim=o.roundOut||o.dead;return (
  <div style={{display:'flex',alignItems:'center',gap:7,padding:'1px 5px 1px 6px',borderLeft:o.active?`3px solid ${o.accent}`:'3px solid transparent',background:o.active?`${o.accent}16`:'transparent',opacity:o.active?1:dim?0.9:0.75,flex:1,minHeight:0}}>
    <span style={{fontFamily:PS,fontSize:7,color:INK+(dim?'0.18)':'0.35)'),width:10,flexShrink:0}}>{i+1}</span>
    <span style={{width:7,height:7,background:o.accent,boxShadow:dim?'none':`0 0 5px ${o.accent}`,opacity:dim?0.3:1,flexShrink:0}}></span>
    <span style={{fontFamily:PS,fontSize:8,color:dim?INK+'0.3)':o.active?'#fff':INK+'0.8)',letterSpacing:0.5,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{midTrunc(o.name.toUpperCase(),16)}</span>
    <span style={{marginLeft:'auto',flexShrink:0,display:'flex',alignItems:'center'}}>
      {o.dead?<span style={{fontFamily:PS,fontSize:7,color:INK+'0.3)',letterSpacing:0.5}}>💀 OUT</span>
       :o.roundOut?<span style={{fontFamily:PS,fontSize:6,color:RED,opacity:0.8,border:`1px solid ${RED}66`,padding:'2px 4px',letterSpacing:0.5}}>ROUND OUT</span>
       :<Hearts lives={o.lives} max={o.maxLives} accent={o.accent} size={13}/>}
    </span>
  </div>);};
// shared rule line — spans the full card so left column and rail align to it
const RuleLine=({s})=>(
  <div style={{display:'flex',alignItems:'center',gap:8,marginTop:10}}>
    {s.variant.indexOf('SURVIVOR')===0&&<span style={{fontFamily:PS,fontSize:6,color:LIME,letterSpacing:1,textShadow:`0 0 6px ${LIME}66`}}>{s.variant}</span>}
    <div style={{flex:1,height:1,background:INK+'0.1)'}}></div>
  </div>
);
const Rail=({s})=>(
  <div style={{width:300,flexShrink:0,borderLeft:`1px solid ${INK}0.12)`,paddingLeft:12,display:'flex',flexDirection:'column'}}>
    {s.players.map((o,i)=><RailRow key={o.handle} o={o} i={i}/>)}
    <div style={{display:'flex',alignItems:'center',gap:8,paddingTop:4,marginTop:3,borderTop:`1px solid ${INK}0.1)`}}>
      <span style={{fontFamily:PS,fontSize:8,color:INK+'0.5)',letterSpacing:1}}>TARGET</span>
      {s.targetBy
        ?<span style={{marginLeft:'auto',fontFamily:PS,fontSize:11,color:YELLOW,textShadow:`0 0 8px ${YELLOW}88`}}>BY {s.targetBy}</span>
        :<span style={{marginLeft:'auto',fontFamily:PS,fontSize:11,color:INK+'0.3)'}}>—</span>}
    </div>
  </div>
);
// card frame (rule 5) — border is ALWAYS the player accent (identity).
// Proposal B lets the GLOW flip semantic; A and C keep it accent.
const OneUpCard=({s,prop='A',helper})=>{
  const p=activeOf(s);
  const sem=s.mode==='safe'?GREEN:s.mode==='cant'?RED:null;
  const glow=(prop==='B'&&sem)?sem:p.accent;
  return (
    <div style={{boxSizing:'border-box',height:250,margin:'12px 14px 10px',padding:'12px 14px',background:SURFACE,
                 border:`3px solid ${p.accent}`,boxShadow:`0 0 ${prop==='B'&&sem?'22px':'14px'} ${glow}${prop==='B'&&sem?'aa':'66'}`,
                 display:'flex',flexDirection:'column',position:'relative',zIndex:2}}>
      <Header s={s} prop={prop} helper={helper}/>
      <RuleLine s={s}/>
      <div style={{flex:1,minHeight:0,display:'flex',gap:14,marginTop:5}}>
        {helper?<LeftColH s={s} prop={prop}/>:<LeftCol s={s} prop={prop}/>}
        <Rail s={s}/>
      </div>
    </div>
  );
};

// ── chrome (approved, context only) ──────────────────────────────
const scan=`repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const TopBar=({s})=>(
  <div style={{padding:'15px 22px',background:'#000',borderBottom:`2px solid ${MAGENTA}`,display:'flex',alignItems:'center',gap:14,position:'relative',zIndex:6}}>
    <div style={{fontFamily:VT,fontSize:19,color:CYAN,letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1,textAlign:'center',fontFamily:PS,fontSize:12,color:YELLOW,letterSpacing:2,textShadow:`0 0 8px ${YELLOW}88`}}>🕹️ 1UP</div>
    <div style={{fontFamily:VT,fontSize:17,color:INK+'0.55)',letterSpacing:2}}>{aliveOf(s)} ALIVE · RND {s.round}</div>
  </div>
);
const Ruler=({label})=>(
  <div style={{position:'absolute',top:0,bottom:0,right:2,width:13,borderTop:`1px solid ${YELLOW}99`,borderBottom:`1px solid ${YELLOW}99`,borderRight:`1px solid ${YELLOW}99`,zIndex:7,pointerEvents:'none'}}>
    <span style={{position:'absolute',top:'50%',right:2,transform:'translateY(-50%)',writingMode:'vertical-rl',fontFamily:PS,fontSize:6,color:YELLOW,letterSpacing:1}}>{label}</span>
  </div>
);
const BoardSlice=({note})=>(
  <div style={{position:'relative',flex:1,overflow:'hidden'}}>
    <div style={{position:'absolute',left:'50%',top:14,transform:'translateX(-50%)',width:420,height:420,borderRadius:'50%',border:`2px dashed ${INK}0.22)`,background:`radial-gradient(circle, rgba(255,0,170,0.1) 0%, transparent 68%)`,display:'flex',justifyContent:'center'}}>
      <span style={{marginTop:34,fontFamily:PS,fontSize:9,color:INK+'0.38)',letterSpacing:2}}>◎ BOARD{note?` · ${note}`:''}</span>
    </div>
  </div>
);
const ZoneFrame=({s,children})=>(
  <div style={{width:W,height:460,background:BG,color:'#fff',fontFamily:PS,overflow:'hidden',position:'relative',display:'flex',flexDirection:'column'}}>
    <div style={{position:'absolute',inset:0,backgroundImage:scan,pointerEvents:'none',zIndex:5}}></div>
    <TopBar s={s}/>
    <div style={{height:ZONE,flexShrink:0,position:'relative',borderBottom:`1px dashed ${INK}0.18)`}}>
      {children}
      <Ruler label="OVERVIEW · 272 PX"/>
    </div>
    <BoardSlice note="TOP EDGE FIXED"/>
  </div>
);

// ── TODAY — faithful to one-up-cockpit.jsx (frame flips, carousel) ─
const TPips=({lives,max,color,size=15})=>(
  <div style={{display:'flex',gap:4,alignItems:'center'}}>
    {Array.from({length:max}).map((_,i)=>(<span key={i} style={{fontFamily:VT,fontSize:size,lineHeight:1,color:i<lives?color:INK+'0.18)',textShadow:i<lives?`0 0 6px ${color}`:'none'}}>{i<lives?'♥':'♡'}</span>))}
  </div>
);
const TPeek=({p})=>(
  <div style={{width:96,flexShrink:0,border:`2px solid ${p.accent}88`,background:`${p.accent}0d`,padding:'11px 9px',opacity:0.82}}>
    <div style={{width:32,height:32,background:BG,border:`2px solid ${p.accent}`,display:'flex',alignItems:'center',justifyContent:'center',fontFamily:PS,fontSize:9,color:p.accent,margin:'0 auto'}}>{p.handle}</div>
    <div style={{fontFamily:VT,fontSize:14,color:'#fff',textAlign:'center',marginTop:6,letterSpacing:1}}>{p.name.toUpperCase()}</div>
    <div style={{display:'flex',justifyContent:'center',marginTop:6}}><TPips lives={p.lives} max={3} color={p.accent} size={13}/></div>
  </div>
);
const TActive=({p})=>{
  const safe=p.mode==='safe', danger=p.mode==='cant';
  const frame=safe?GREEN:danger?RED:p.accent;
  const need=p.target!=null?Math.max(0,p.target-p.turnTotal):null;
  return (
    <div style={{position:'relative',border:`3px solid ${frame}`,background:`linear-gradient(180deg, ${frame}1c 0%, ${frame}05 100%)`,boxShadow:`0 0 20px ${frame}55`,padding:'12px 16px 14px',flex:1,minWidth:0}}>
      <div style={{position:'absolute',top:-9,left:16,padding:'3px 9px',background:frame,color:BG,fontFamily:PS,fontSize:9,letterSpacing:1.5,boxShadow:`0 0 8px ${frame}aa`}}>▶ NOW THROWING</div>
      <div style={{display:'flex',alignItems:'center',gap:13,marginTop:3}}>
        <div style={{width:48,height:48,background:BG,border:`3px solid ${p.accent}`,display:'flex',alignItems:'center',justifyContent:'center',fontFamily:PS,fontSize:13,color:p.accent,textShadow:`0 0 8px ${p.accent}aa`,flexShrink:0}}>{p.handle}</div>
        <div style={{flex:1,minWidth:0}}>
          <div style={{fontFamily:PS,fontSize:16,color:'#fff',letterSpacing:2,lineHeight:1}}>{p.name.toUpperCase()}</div>
          <div style={{marginTop:8}}><TPips lives={p.lives} max={3} color={p.accent}/></div>
        </div>
        <div style={{textAlign:'right',flexShrink:0}}>
          <div style={{fontFamily:PS,fontSize:9,color:INK+'0.5)',letterSpacing:1}}>THIS TURN</div>
          <div style={{fontFamily:PS,fontSize:34,color:safe?GREEN:p.accent,lineHeight:1,textShadow:`0 0 14px ${(safe?GREEN:p.accent)}aa`,marginTop:4}}>{p.turnTotal}</div>
        </div>
      </div>
      <div style={{marginTop:12}}>
        {safe
          ?<div style={{display:'flex',alignItems:'center',gap:8}}><span style={{fontFamily:PS,fontSize:28,color:GREEN,letterSpacing:1,textShadow:`0 0 16px ${GREEN}`}}>SAFE</span><span style={{fontFamily:PS,fontSize:20,color:GREEN}}>✓</span></div>
          :<React.Fragment><div style={{fontFamily:PS,fontSize:12,color:danger?RED:INK+'0.6)',letterSpacing:2}}>BEAT</div>
           <div style={{fontFamily:PS,fontSize:52,color:danger?RED:'#fff',letterSpacing:-2,lineHeight:0.95,marginTop:4,textShadow:`0 0 18px ${danger?RED:p.accent}88`}}>{p.target}</div></React.Fragment>}
      </div>
      <div style={{marginTop:11,padding:'8px 12px',display:'flex',alignItems:'center',gap:10,background:safe?`${GREEN}18`:danger?`${RED}18`:'rgba(255,255,255,0.05)',border:`2px solid ${safe?GREEN:danger?RED:INK+'0.14)'}`}}>
        {safe&&<span style={{fontFamily:PS,fontSize:10,color:GREEN,letterSpacing:1}}>BEAT {p.target} · REMAINING DARTS PAD THE NEW TARGET</span>}
        {danger&&<React.Fragment><span style={{fontFamily:PS,fontSize:11,color:RED,letterSpacing:1,textShadow:`0 0 8px ${RED}`}}>CAN'T BEAT</span><span style={{fontFamily:VT,fontSize:16,color:'#ff8fa6'}}>· LIFE AT RISK · need {need}, max 60</span></React.Fragment>}
      </div>
    </div>
  );
};
const TodayFrame=({p,note})=>(
  <div style={{width:W,height:460,background:BG,color:'#fff',fontFamily:PS,overflow:'hidden',position:'relative',display:'flex',flexDirection:'column'}}>
    <div style={{position:'absolute',inset:0,backgroundImage:scan,pointerEvents:'none',zIndex:5}}></div>
    <TopBar s={{players:[{},{},{},{}],round:3}}/>
    <div style={{padding:'14px 14px 0',position:'relative',zIndex:6,display:'flex',alignItems:'stretch',gap:10}}>
      <TPeek p={mkP('Jonas','JON',CYAN,3)}/>
      <TActive p={p}/>
      <TPeek p={mkP('Per','PER',GREEN,3)}/>
    </div>
    <div style={{display:'flex',justifyContent:'center',gap:7,marginTop:10,position:'relative',zIndex:6}}>
      {[0,1,2,3].map(i=>(<div key={i} style={{width:i===1?22:8,height:8,borderRadius:4,background:i===1?p.accent:INK+'0.4)',boxShadow:i===1?`0 0 6px ${p.accent}`:'none'}}></div>))}
    </div>
    <div style={{position:'relative',zIndex:6,margin:'6px 14px 0',borderTop:`2px dashed ${RED}aa`,paddingTop:4,textAlign:'right'}}>
      <span style={{fontFamily:PS,fontSize:7,color:RED,letterSpacing:1}}>{note}</span>
    </div>
    <BoardSlice/>
  </div>
);

// ── full cockpit ─────────────────────────────────────────────────
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
    <TopBar s={s}/>
    <div style={{height:ZONE,flexShrink:0,position:'relative'}}><OneUpCard s={s} prop="A"/><Ruler label="272 PX"/></div>
    <div style={{flex:1,position:'relative',display:'flex',alignItems:'center',justifyContent:'center',paddingBottom:84}}>
      <div style={{position:'absolute',width:520,height:520,borderRadius:'50%',background:'radial-gradient(circle, rgba(255,0,170,0.16) 0%, transparent 68%)',pointerEvents:'none'}}></div>
      <div style={{width:430,height:430,borderRadius:'50%',border:`2px dashed ${INK}0.2)`,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:9}}>
        <div style={{fontFamily:PS,fontSize:12,color:INK+'0.4)',letterSpacing:2}}>◎ DARTBOARD</div>
        <div style={{fontFamily:VT,fontSize:17,color:INK+'0.32)',letterSpacing:1}}>approved chrome · out of scope</div>
      </div>
    </div>
    <ActionBar/>
  </div>
);

// ── spec / fasit ─────────────────────────────────────────────────
const SRow=({k,v})=>(
  <div style={{display:'flex',gap:12,padding:'7px 0',borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{width:158,flexShrink:0,fontFamily:'"Inter",sans-serif',fontSize:12,fontWeight:800,color:'#2a251f'}}>{k}</div>
    <div style={{flex:1,fontFamily:'"Inter",sans-serif',fontSize:12,lineHeight:1.45,color:'#5a544a'}}>{v}</div>
  </div>
);
const SpecCard=()=>(
  <div style={{boxSizing:'border-box',width:720,height:H,background:'#fffdf6',border:'1.5px solid rgba(0,0,0,0.14)',padding:'30px 34px',fontFamily:'"Inter",system-ui,sans-serif',display:'flex',flexDirection:'column',gap:13,overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono",monospace',fontSize:11,letterSpacing:2,color:'#c96442',textTransform:'uppercase',fontWeight:600,marginBottom:6}}>1UP overview · mode round 2/5 · fasit</div>
      <div style={{fontFamily:'"Archivo","Inter",sans-serif',fontSize:25,fontWeight:900,letterSpacing:-0.5,color:'#2a251f',lineHeight:1.1}}>Forslag A — status-platen bærer staten (anbefalt)</div>
    </div>
    <div style={{padding:'12px 14px',background:'#2a251f'}}>
      <div style={{fontFamily:'"JetBrains Mono",monospace',fontSize:13,fontWeight:700,color:'#C6FF3C',lineHeight:1.5}}>OVERVIEW ZONE: h=272 px @ 820×1180 — all states fit, no growth</div>
    </div>
    <div>
      <SRow k="Arvet fra X01 (B)" v="Kort 250px fast + marger 14/12/14/10. Ramme regel 5: surface-fill, 3px border — ALLTID spillerens accent (identitet flipper aldri). Header regel 4 verbatim: foto-avatar 56px, navnkurve 18/15/12/10, pips + DART n/3. Skinne 300px høyre. Alt alltid rendret (regel 2)."/>
      <SRow k="Primærtall (regel 6)" v={<span><b>BEAT &lt;target&gt;</b> 60px PS i spiller-accent m/ glow. Free throw (spillstart / SURVIVOR-rundestart): samme slot viser <b>SET THE TARGET</b> i lime (1UP-brand, regel 7) — ingen vekst.</span>}/>
      <SRow k="Semantiske states (valgt A)" v={<span>Status-platen (alltid rendret, min 52px, nederst i venstre kolonne) bærer SAFE/CAN'T BEAT: fylt <b>grønn «SAFE ✓ · NEW TARGET n»</b> / <b>rød «CAN'T BEAT · need n · max m»</b>. Nøytral: gul «NEED n MORE · x darts left». Free: cyan hint-linje. Ramme + glow beholder accent — identitet og state deler aldri kanal.</span>}/>
      <SRow k="Venstre kolonne" v="THIS TURN (VT-28, accent; dimmet 0.34 før første dart) · LIVES (♥ 22px i accent; 1 liv = rødt hjerte + LAST LIFE-tag — persistent fare, uavhengig av platen) · status-platen."/>
      <SRow k="Skinne — sortering" v={<span><b>Throw order</b> (designvalg, brief-en ba oss velge): target-kjeden følger kastrekkefølgen (BEAT THE LAST = forrige spillers total), lives-uavgjort gjør en ladder meningsløs, og radene står stille gjennom elimineringer. Rad = nr + accent-dot + navn + ♥-pips (1 liv = rødt hjerte).</span>}/>
      <SRow k="Skinne — states" v={<span><b>ROUND OUT</b> (SURVIVOR): dot/navn dimmet 0.3, rød omriss-tag «ROUND OUT» — accent-dotene beholder hierarkiet. <b>Eliminert:</b> 💀 OUT, hele raden dim. Bunnrad: <b>TARGET BY &lt;navn&gt;</b> (gul) — hvem satte målet; «—» dimmet i free throw.</span>}/>
      <SRow k="Stress: navn" v="Navnkurven bunner på 10px >16 tegn i header; skinnen midt-kutter til 16 tegn (start + slutt beholdes). Testet: «Alexander the boss bitch» (24 tegn)."/>
      <SRow k="Ikke vist (besluttet)" v="Kumulativ dart-count, poeng (1UP har ingen), turhistorikk utover THIS TURN. Variant-label (BEAT THE LAST / SURVIVOR · RND n) står i lime over skinnen."/>
      <SRow k="PROPOSAL · A+ (KISS)" v={<span>Lives (♥ + ev. LAST LIFE) flyttes opp ved navnet. <b>THIS TURN</b> viser <b>total / mål</b> («71 / 118») i VT-38. HIT-forslaget — laveste enkeltfelt som slår målet — står inne i platen etter NEED n MORE («NEED 47 MORE ▶ T16 +»); «T16 +» når eksakt ikke finnes. Ny data utenfor brief-en — trenger sign-off; implementasjon eier forslags-algoritmen.</span>}/>
    </div>
    <div style={{padding:'11px 14px',background:'#eae6f5',border:'1px solid rgba(90,70,150,0.28)'}}>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,color:'#3a2f5a',lineHeight:1.55}}><b>Hvorfor A (over B/C):</b> platen er en dedikert, oche-lesbar statuskanal — P1-status i brief-en. B (glød flipper) flommer hele kortet og svekker skillet identitet/state; C (tallet flipper) gir ingen flipp i nøytral state og stjeler accent-kanalen fra tallet. A lar rød LAST LIFE, rød ROUND OUT og grønn/rød plate sameksistere uten kollisjon.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:11,fontWeight:800,color:'#8a8378',textTransform:'uppercase',letterSpacing:0.5,marginBottom:4}}>Stress-states på artboardet</div>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,color:'#5a544a',lineHeight:1.6}}>Free throw (SET THE TARGET) · SAFE mid-turn · CAN'T BEAT (begge i forslags-seksjonen) · aktiv på siste liv (+ én eliminert i skinnen) · 6 spillere / 2 ROUND OUT (SURVIVOR) · lengste navn (24 tegn).</div>
    </div>
    <div style={{marginTop:'auto',padding:'12px 14px',background:'#dcefe1',border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,lineHeight:1.55,color:'#2a4a36'}}><b>Implementasjon eier:</b> variant-oppførsel (BEAT THE LAST / SURVIVOR), tie-logikk (≥ = SAFE), <b>DossedartOneUpActiveCard</b>-omskriving og fixed-height-regresjonstesten som pinner 272px. Tokens only · Press Start 2P / VT323 · no border-radius · English strings · lime aldri spillerfarge.</div>
    </div>
  </div>
);

// ── canvas ───────────────────────────────────────────────────────
const OneUpOverviewRound=()=>(
  <React.Fragment>
    <DCSection id="ouo-today" title="Dagens 1UP-overview" subtitle="Som den skipper: hele kort-rammen flipper grønn/rød — spillerens accent (identitet) forsvinner akkurat når det gjelder. Karusellen viser bare naboene, ikke alle spillere, og sonehøyden varierer med state. Begge deler løses av X01-skjelettet.">
      <DCArtboard id="today-safe" label="I dag · SAFE — rammen blir grønn, identiteten borte" width={W} height={460}><TodayFrame p={{...mkP('Kari','KAR',MAGENTA,2),mode:'safe',target:87,turnTotal:92}} note="◀ FRAME = STATE → PLAYER ACCENT LOST · NO FULL STANDINGS"/></DCArtboard>
      <DCArtboard id="today-cant" label="I dag · CAN'T BEAT — samme problem i rødt" width={W} height={460}><TodayFrame p={{...mkP('Kari','KAR',MAGENTA,2),mode:'cant',target:145,turnTotal:30}} note="◀ ZONE HEIGHT VARIES BY STATE · BOARD EDGE MOVES"/></DCArtboard>
    </DCSection>
    <DCSection id="ouo-props" title="Brief-ens ene spørsmål: hva bærer SAFE / CAN'T BEAT?" subtitle="Rammen er nå identitet (spiller-accent, regel 3/5) og kan ikke flippe. Tre kandidater, hver vist i grønn og rød state. A — status-platen fylles (anbefalt). B — gløden + tint flipper, border beholder accent. C — primærtallet flipper farge. Alt annet er identisk arv fra X01-B.">
      <DCArtboard id="pa-safe" label="A1 · STATUS-PLATEN bærer staten · SAFE ★ ANBEFALT" width={W} height={460}><ZoneFrame s={ST.safe}><OneUpCard s={ST.safe} prop="A"/></ZoneFrame></DCArtboard>
      <DCArtboard id="pa-cant" label="A2 · plate · CAN'T BEAT" width={W} height={460}><ZoneFrame s={ST.cant}><OneUpCard s={ST.cant} prop="A"/></ZoneFrame></DCArtboard>
      <DCArtboard id="pb-safe" label="B1 · GLØDEN flipper · SAFE" width={W} height={460}><ZoneFrame s={ST.safe}><OneUpCard s={ST.safe} prop="B"/></ZoneFrame></DCArtboard>
      <DCArtboard id="pb-cant" label="B2 · glød · CAN'T BEAT" width={W} height={460}><ZoneFrame s={ST.cant}><OneUpCard s={ST.cant} prop="B"/></ZoneFrame></DCArtboard>
      <DCArtboard id="pc-safe" label="C1 · PRIMÆRTALLET flipper · SAFE" width={W} height={460}><ZoneFrame s={ST.safe}><OneUpCard s={ST.safe} prop="C"/></ZoneFrame></DCArtboard>
      <DCArtboard id="pc-cant" label="C2 · tall · CAN'T BEAT" width={W} height={460}><ZoneFrame s={ST.cant}><OneUpCard s={ST.cant} prop="C"/></ZoneFrame></DCArtboard>
    </DCSection>
    <DCSection id="ouo-helper" title="PROPOSAL — A+ (KISS): lives ved navnet, total / mål, HIT i platen" subtitle="Lives flyttes opp ved siden av navnet. THIS TURN får plassen og viser total / mål — hva du har kontra hva du trenger, i ett blikk. HIT-forslaget står i platen etter NEED n MORE. Ny data utenfor brief-en (trenger sign-off); implementasjon eier forslags-algoritmen.">
      <DCArtboard id="hp-need" label="A+ · NEED 45 MORE ▶ T15 · 42 / 87" width={W} height={460}><ZoneFrame s={ST.need}><OneUpCard s={{...ST.need,hit:'T15'}} prop="A" helper/></ZoneFrame></DCArtboard>
      <DCArtboard id="hp-lastlife" label="A+ · siste liv · NEED 47 MORE ▶ T16 + · 71 / 118" width={W} height={460}><ZoneFrame s={ST.lastlife}><OneUpCard s={{...ST.lastlife,hit:'T16 +'}} prop="A" helper/></ZoneFrame></DCArtboard>
      <DCArtboard id="hp-safe" label="A+ · SAFE · 92 / 87" width={W} height={460}><ZoneFrame s={ST.safe}><OneUpCard s={ST.safe} prop="A" helper/></ZoneFrame></DCArtboard>
    </DCSection>
    <DCSection id="ouo-stress" title="Stress-states — forslag A" subtitle="SAFE og CAN'T BEAT står i forslags-seksjonen over; her er resten av brief-ens liste. Samme 272px uten vekst: platen er alltid rendret, THIS TURN dimmer før første dart, skinnen holder radene i ro.">
      <DCArtboard id="st-free" label="1 · Free throw — SET THE TARGET (spillstart, intet mål)" width={W} height={460}><ZoneFrame s={ST.free}><OneUpCard s={ST.free} prop="A"/></ZoneFrame></DCArtboard>
      <DCArtboard id="st-lastlife" label="2 · Aktiv på siste liv (persistent fare) + én eliminert i skinnen" width={W} height={460}><ZoneFrame s={ST.lastlife}><OneUpCard s={ST.lastlife} prop="A"/></ZoneFrame></DCArtboard>
      <DCArtboard id="st-survivor" label="3 · SURVIVOR · 6 spillere · 2 ROUND OUT" width={W} height={460}><ZoneFrame s={ST.survivor}><OneUpCard s={ST.survivor} prop="A"/></ZoneFrame></DCArtboard>
      <DCArtboard id="st-longname" label="4 · Lengste navn (24 tegn → 10px-kurve + midt-kutt i skinnen)" width={W} height={460}><ZoneFrame s={ST.longname}><OneUpCard s={ST.longname} prop="A"/></ZoneFrame></DCArtboard>
    </DCSection>
    <DCSection id="ouo-full" title="Full cockpit — forslag A" subtitle="SURVIVOR max-state (6 spillere, 2 ROUND OUT, SAFE): brettet får samme topp-kant som X01. Fasit ved siden av.">
      <DCArtboard id="full-a" label="Cockpit · A · SURVIVOR SAFE" width={W} height={H}><FullCockpit s={ST.fullSafe}/></DCArtboard>
      <DCArtboard id="spec" label="Spec · fasit" width={720} height={H}><SpecCard/></DCArtboard>
    </DCSection>
  </React.Fragment>
);
window.OneUpOverviewRound=OneUpOverviewRound;
