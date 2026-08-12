// DOSSEDART — Golf overview round (mode round 4 · 2026-07-22) · KISS-iterasjon
// Evolution of the QA-passed cockpit v2. Deltas vs v2:
//   D1 rule-4 header in the hero + the HOLE number moved UP beside the name
//   D2 dart chips in the status plate (per-dart history, no ladder, no prose)
//   D3 status plate = the state channel; hero frame = player accent, never flips
//   D4 pinned zone budget; playoff fills the strip zone with the 19→20→BULL chain
//   D5 leaderboard: fixed zone, rows fill ≤5 players, SCROLL when >5
//   D6 YOUR CARD: all 18 holes, side-scroll (auto-centers current hole)
const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', BG='#0a0014', PHOSPHOR='#D9D2C2';
const GOLF=GREEN, PAR=3;
const INK='rgba(255,255,255,';
const PS='"Press Start 2P", monospace';
const VT='"VT323", monospace';
const W=820, H=1180;
// pinned zone budget @ 820×1180 (fasit):
// TOPBAR 64 ·14· HERO 244 ·12· BOARD 394 ·12· STRIP 96 ·12· CONSOLE 220 ·12· ACTIONBAR-band 100 = 1180
const nameSize=(n)=>n.length<=8?18:n.length<=12?15:n.length<=16?12:10;
const midTrunc=(n,max)=>n.length<=max?n:n.slice(0,Math.ceil((max-1)*0.6))+'…'+n.slice(n.length-Math.floor((max-1)*0.4));
const termFor=(strokes)=>{
  if(strokes===1) return {term:'ACE',col:CYAN};
  const v=strokes-PAR;
  if(v<=-1) return {term:'BIRDIE',col:GREEN};
  if(v===0) return {term:'PAR',col:PHOSPHOR};
  if(v===1) return {term:'BOGEY',col:ORANGE};
  if(v===2) return {term:'DOUBLE BOGEY',col:RED};
  return {term:'TRIPLE BOGEY',col:RED};
};
const zoneTerm=(z)=> z==='✗'?{term:'MISS',col:RED}: (z[0]==='T'||z==='50')?{term:'ACE',col:CYAN}: (z[0]==='D'||z==='25')?{term:'BIRDIE',col:GREEN}:{term:'PAR',col:PHOSPHOR};
const relPar=(v)=>v===0?'E':v>0?`+${v}`:`${v}`;
const relCol=(v)=>v<0?GREEN:v>0?ORANGE:PHOSPHOR;

// ── chrome (reused verbatim from v2) ────────────────────────────
const scan3=`repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const Frame3=({children})=>(
  <div style={{width:W,height:H,background:BG,color:'#fff',fontFamily:PS,display:'flex',flexDirection:'column',overflow:'hidden',position:'relative'}}>
    <div style={{position:'absolute',inset:0,backgroundImage:scan3,pointerEvents:'none',zIndex:5}}></div>
    <div style={{position:'absolute',inset:0,background:'radial-gradient(ellipse at center, transparent 52%, rgba(0,0,0,0.62) 100%)',pointerEvents:'none',zIndex:4}}></div>
    {children}
  </div>
);
const TopBar3=({hole,holes,playoff})=>(
  <div style={{height:64,boxSizing:'border-box',padding:'15px 22px',background:'#000',borderBottom:`2px solid ${MAGENTA}`,display:'flex',alignItems:'center',gap:14,position:'relative',zIndex:6}}>
    <div style={{fontFamily:VT,fontSize:19,color:CYAN,letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1,textAlign:'center',fontFamily:PS,fontSize:13,color:GOLF,letterSpacing:2,textShadow:`0 0 8px ${GOLF}88`}}>⛳ GOLF</div>
    <div style={{fontFamily:playoff?PS:VT,fontSize:playoff?12:17,color:playoff?RED:INK+'0.55)',letterSpacing:2,textShadow:playoff?`0 0 8px ${RED}88`:'none'}}>{playoff?'PLAYOFF':`HOLE ${hole}/${holes}`}</div>
  </div>
);
const ActionBar3=()=>(
  <div style={{position:'absolute',left:0,right:0,bottom:0,padding:'13px 16px 17px',background:'#000',borderTop:`2px solid ${YELLOW}`,display:'flex',gap:12,zIndex:6}}>
    <div style={{flex:1,padding:'16px 8px',border:`2px solid ${MAGENTA}`,fontFamily:PS,fontSize:12,color:'#fff',letterSpacing:1,textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:1,padding:'16px 8px',border:`2px solid ${CYAN}`,fontFamily:PS,fontSize:12,color:CYAN,letterSpacing:1,textAlign:'center'}}>✗ MISS</div>
    <div style={{flex:1,padding:'16px 8px',border:`2px solid ${INK}0.35)`,fontFamily:PS,fontSize:12,color:INK+'0.7)',letterSpacing:1,textAlign:'center'}}>⋯ MENU</div>
  </div>
);

// ── rule-4 header parts ─────────────────────────────────────────
const PhotoAvatar3=({size,handle,accent})=>(
  <div style={{width:size,height:size,flexShrink:0,border:`2px solid ${accent}`,position:'relative',background:`repeating-linear-gradient(135deg, #1c0033 0, #1c0033 4px, #130024 4px, #130024 8px)`,display:'flex',alignItems:'center',justifyContent:'center'}}>
    <span style={{fontFamily:VT,fontSize:size*0.42,color:INK+'0.42)',letterSpacing:1}}>{handle}</span>
    <span style={{position:'absolute',bottom:2,right:3,fontFamily:VT,fontSize:9,color:INK+'0.28)'}}>▨</span>
  </div>
);
const DartPips3=({accent,thrown})=>(
  <div style={{display:'flex',alignItems:'center',gap:8}}>
    <div style={{display:'flex',gap:6}}>
      {[0,1,2].map(i=>(<div key={i} style={{width:11,height:11,background:i<thrown?accent:'transparent',border:`2px solid ${i<thrown?accent:INK+'0.3)'}`,boxShadow:i<thrown?`0 0 6px ${accent}aa`:'none'}}/>))}
    </div>
    <span style={{fontFamily:VT,fontSize:15,color:INK+'0.5)',letterSpacing:1}}>DART {Math.min(thrown+1,3)}/3</span>
  </div>
);

// ── D2 dart chip — per-dart history, lives inside the plate ─────
const Chip3=({rec,dark})=>{
  const t=rec?zoneTerm(rec.z):null;
  const col=dark?BG:(rec?t.col:INK+'0.35)');
  return (
    <span style={{width:36,height:36,boxSizing:'border-box',flexShrink:0,display:'inline-flex',alignItems:'center',justifyContent:'center',fontFamily:rec?PS:VT,fontSize:rec?10:16,color:col,border:`2px solid ${dark?BG:(rec?t.col:INK+'0.14)')}`,background:dark?'transparent':(rec?`${t.col}16`:'transparent'),opacity:dark&&!rec?0.45:1}}>{rec?rec.z:'·'}</span>
  );
};

// ── D3 status plate — always rendered, 56px, chips + state ──────
const Plate3=({mode,lie,darts,next,wash})=>{
  const t=lie!=null?termFor(lie):null;
  const left=3-darts.length;
  const base={height:56,boxSizing:'border-box',flexShrink:0,display:'flex',alignItems:'center',gap:12,padding:'0 12px',position:'relative',overflow:'hidden'};
  const chips=(dark)=><span style={{display:'inline-flex',gap:6}}>{[0,1,2].map(i=><Chip3 key={i} rec={darts[i]} dark={dark}/>)}</span>;
  if(mode==='result') return (
    <div style={{...base,border:`2px solid ${t.col}`,background:t.col,color:BG}}>
      {chips(true)}
      <span style={{fontFamily:PS,fontSize:15,letterSpacing:1}}>LYING {lie}</span>
      <span style={{fontFamily:PS,fontSize:12,letterSpacing:1}}>{t.term}{wash?' · WASH':''}</span>
      <span style={{flex:1}}/>
      <span style={{fontFamily:VT,fontSize:21,letterSpacing:1}}>NEXT ▸ {next}</span>
      <div style={{position:'absolute',left:0,bottom:0,height:4,width:'62%',background:BG,opacity:0.55}}/>
    </div>);
  const scored=lie!=null;
  return (
    <div style={{...base,border:`2px solid ${scored?t.col:INK+'0.16)'}`,background:scored?`${t.col}16`:'rgba(255,255,255,0.04)'}}>
      {chips(false)}
      {mode==='teeoff'
        ? <span style={{fontFamily:VT,fontSize:22,color:INK+'0.7)',letterSpacing:1}}>▸ TEE OFF · <b style={{color:'#fff'}}>LAST DART COUNTS</b></span>
        : scored
          ? <React.Fragment>
              <span style={{fontFamily:PS,fontSize:15,color:'#fff',letterSpacing:1}}>LYING {lie}</span>
              <span style={{fontFamily:PS,fontSize:12,color:t.col,letterSpacing:1,textShadow:`0 0 8px ${t.col}`}}>{t.term}</span>
            </React.Fragment>
          : <span style={{fontFamily:PS,fontSize:12,color:INK+'0.6)',letterSpacing:1}}>NO SCORE</span>}
      <span style={{flex:1}}/>
      {mode!=='teeoff'&&<span style={{fontFamily:PS,fontSize:12,color:YELLOW,letterSpacing:1,textShadow:`0 0 6px ${YELLOW}88`}}>{left} DART{left===1?'':'S'} LEFT</span>}
    </div>);
};

// ── HERO — 244px: name + HOLE number side by side, plate below ──
const Hero3=({p,hole,darts,lie,mode,target,playoff,next,wash})=>{
  const aim=target!=null?target:hole;
  return (
    <div style={{height:244,boxSizing:'border-box',margin:'14px 16px 0',border:`3px solid ${p.accent}`,background:'rgba(255,255,255,0.02)',padding:'12px 16px',display:'flex',flexDirection:'column',overflow:'hidden'}}>
      <div style={{flex:1,minHeight:0,display:'flex',alignItems:'center',gap:16}}>
        <PhotoAvatar3 size={56} handle={p.handle} accent={p.accent}/>
        <div style={{flex:1,minWidth:0}}>
          <div style={{fontFamily:PS,fontSize:nameSize(p.name),color:'#fff',letterSpacing:1.5,lineHeight:1.25,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{p.name.toUpperCase()}</div>
          <div style={{marginTop:10}}><DartPips3 accent={p.accent} thrown={darts.length}/></div>
        </div>
        <div style={{flexShrink:0,textAlign:'center',paddingRight:6}}>
          <div style={{fontFamily:PS,fontSize:9,color:INK+'0.5)',letterSpacing:2,marginBottom:14}}>{playoff?'PLAYOFF':`HOLE · PAR ${PAR}`}</div>
          <div style={{fontFamily:PS,fontSize:aim==='BULL'?58:120,color:GOLF,lineHeight:0.82,textShadow:`0 0 30px ${GOLF}bb, 5px 5px 0 rgba(0,0,0,0.55)`,letterSpacing:aim==='BULL'?0:-4}}>{aim}</div>
        </div>
      </div>
      <Plate3 mode={mode} lie={lie} darts={darts} next={next} wash={wash}/>
    </div>
  );
};

// ── LEADERBOARD — compact rows (v2 density) · scroll >5 ─────────
const Board3=({players,hole,playoff})=>{
  const ordered=[...players].sort((a,b)=>a.total-b.total);
  const scroll=ordered.length>5;
  return (
    <div style={{boxSizing:'border-box',margin:'12px 16px 0',border:`2px solid ${INK}0.14)`,display:'flex',flexDirection:'column',overflow:'hidden',maxHeight:34+56*5+2,flexShrink:0}}>
      <div style={{height:34,boxSizing:'border-box',display:'flex',alignItems:'center',justifyContent:'space-between',padding:'0 14px',background:'rgba(255,255,255,0.03)',borderBottom:`2px solid ${INK}0.14)`,flexShrink:0}}>
        <span style={{fontFamily:PS,fontSize:10,color:INK+'0.7)',letterSpacing:2}}>{playoff?'PLAYOFF · TIED LEADERS':'LEADERBOARD'}</span>
        {scroll
          ? <span style={{fontFamily:VT,fontSize:16,color:YELLOW,letterSpacing:1}}>▼ {ordered.length} PLAYERS · SCROLL</span>
          : <span style={{fontFamily:VT,fontSize:16,color:INK+'0.4)',letterSpacing:2}}>LOWEST WINS</span>}
      </div>
      <div style={{overflow:'hidden'}}>
        {ordered.map((p,i)=>{
          const st=p.holeStroke;
          const hs=st!=null?termFor(st):null;
          return (
            <div key={p.handle} style={{height:56,boxSizing:'border-box',display:'grid',gridTemplateColumns:'30px 14px 1fr 56px 140px',alignItems:'center',gap:10,padding:'0 14px',background:p.active?`${p.accent}14`:'transparent',borderBottom:i<ordered.length-1?`1px solid ${INK}0.08)`:'none',borderLeft:p.active?`4px solid ${p.accent}`:'4px solid transparent'}}>
              <span style={{fontFamily:PS,fontSize:15,color:i===0?YELLOW:INK+'0.4)',textShadow:i===0?`0 0 8px ${YELLOW}88`:'none'}}>{i+1}</span>
              <span style={{width:10,height:10,background:p.accent}}/>
              <span style={{fontFamily:PS,fontSize:14,color:p.active?p.accent:'#fff',letterSpacing:1,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',textShadow:p.active?`0 0 8px ${p.accent}66`:'none'}}>{midTrunc(p.name,16).toUpperCase()}</span>
              <span style={{textAlign:'center'}}>
                {st!=null
                  ? <span style={{fontFamily:PS,fontSize:12,color:hs.col,padding:'4px 10px',border:`1.5px solid ${hs.col}`,background:`${hs.col}18`}}>{st}</span>
                  : <span style={{fontFamily:VT,fontSize:17,color:INK+'0.25)',letterSpacing:1}}>·</span>}
              </span>
              <span style={{textAlign:'right',whiteSpace:'nowrap'}}>
                <span style={{fontFamily:PS,fontSize:24,color:'#fff'}}>{p.total}</span>
                <span style={{fontFamily:PS,fontSize:15,color:relCol(p.vsPar),marginLeft:10,textShadow:`0 0 6px ${relCol(p.vsPar)}55`}}>{relPar(p.vsPar)}</span>
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ── STRIP zone (96px) — ALL 18 holes, side-scroll (D6) ──────────
const Strip3=({card,hole})=>{
  const cellW=72, gap=6;
  const total=18*(cellW+gap)-gap;
  const vis=W-32;
  const off=Math.max(0,Math.min((hole-1)*(cellW+gap)-(vis-cellW)/2,total-vis));
  return (
    <div style={{height:96,boxSizing:'border-box',margin:'12px 16px 0',overflow:'hidden'}}>
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:6}}>
        <span style={{fontFamily:PS,fontSize:10,color:INK+'0.6)',letterSpacing:1.5}}>YOUR CARD <span style={{fontFamily:VT,fontSize:15,color:INK+'0.35)',letterSpacing:1}}>· ‹ SWIPE ›</span></span>
        <span style={{fontFamily:PS,fontSize:11,color:CYAN,letterSpacing:1,padding:'4px 11px',border:`2px solid ${CYAN}`,textShadow:`0 0 6px ${CYAN}88`}}>SCORECARD ▸</span>
      </div>
      <div style={{overflow:'hidden'}}>
        <div style={{display:'flex',gap,width:total,transform:`translateX(-${off}px)`}}>
          {Array.from({length:18},(_,i)=>i+1).map(h=>{
            const st=card[h-1];
            const played=st!=null, cur=h===hole;
            const t=played?termFor(st):null;
            return (
              <div key={h} style={{width:cellW,flexShrink:0,textAlign:'center'}}>
                <div style={{fontFamily:VT,fontSize:15,color:cur?YELLOW:INK+'0.4)',marginBottom:2}}>{h}</div>
                <div style={{height:40,display:'flex',alignItems:'center',justifyContent:'center',border:`2px solid ${cur?YELLOW:played?t.col:INK+'0.12)'}`,background:cur?`${YELLOW}1c`:played?`${t.col}16`:'transparent',boxShadow:cur?`0 0 10px ${YELLOW}66`:'none',fontFamily:PS,fontSize:15,color:cur?YELLOW:played?t.col:INK+'0.25)'}}>{played?st:cur?'▶':'·'}</div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
const Chain3=({stage})=>{
  const steps=['19','20','BULL'];
  return (
    <div style={{height:96,boxSizing:'border-box',margin:'12px 16px 0',overflow:'hidden'}}>
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:6}}>
        <span style={{fontFamily:PS,fontSize:10,color:RED,letterSpacing:1.5,textShadow:`0 0 6px ${RED}66`}}>SUDDEN DEATH</span>
        <span style={{fontFamily:VT,fontSize:16,color:INK+'0.45)',letterSpacing:1}}>TIE ▸ NEXT</span>
      </div>
      <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:6}}>
        {steps.map((z,i)=>{
          const done=i<stage, cur=i===stage;
          return (
            <div key={z} style={{height:58,boxSizing:'border-box',display:'flex',alignItems:'center',justifyContent:'center',gap:10,border:`2px solid ${cur?RED:done?INK+'0.3)':INK+'0.12)'}`,background:cur?`${RED}1a`:'transparent',boxShadow:cur?`0 0 12px ${RED}55`:'none'}}>
              <span style={{fontFamily:PS,fontSize:cur?18:14,color:cur?RED:done?INK+'0.55)':INK+'0.25)',textShadow:cur?`0 0 8px ${RED}88`:'none'}}>{z}</span>
              <span style={{fontFamily:VT,fontSize:15,color:cur?'#fff':done?INK+'0.4)':INK+'0.22)',letterSpacing:1}}>{done?'✓ TIED':cur?'▶ NOW':'·'}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ── INPUT CONSOLE — S/D/T + ✗ MISS lifted in (PROPOSAL) ─────────
const Console3=({target,bull})=>{
  const cells=bull
    ? [{z:'25',stroke:2},{z:'50',stroke:1},{z:'✗',miss:true}]
    : [{z:`S${target}`,stroke:3},{z:`D${target}`,stroke:2},{z:`T${target}`,stroke:1},{z:'✗',miss:true}];
  return (
    <div style={{height:220,boxSizing:'border-box',margin:'12px 16px 100px',border:`3px solid ${GOLF}`,boxShadow:`0 0 28px ${GOLF}44, inset 0 0 40px ${GOLF}0d`,background:'rgba(61,255,142,0.03)',display:'flex',flexDirection:'column',overflow:'hidden'}}>
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'9px 16px',background:`${GOLF}1c`,borderBottom:`2px solid ${GOLF}66`,flexShrink:0}}>
        <span style={{fontFamily:PS,fontSize:13,color:GOLF,letterSpacing:2,textShadow:`0 0 8px ${GOLF}aa`}}>▼ TAP TO SCORE</span>
        <span style={{fontFamily:VT,fontSize:18,color:INK+'0.6)',letterSpacing:1}}>THROW AT <b style={{color:'#fff',fontFamily:PS,fontSize:12}}>{bull?'BULL':target}</b></span>
      </div>
      <div style={{flex:1,minHeight:0,display:'grid',gridTemplateColumns:`repeat(${cells.length},1fr)`,gap:12,padding:'12px 14px 14px'}}>
        {cells.map(cel=>{
          const t=cel.miss?{term:'MISS',col:RED}:termFor(cel.stroke);
          return (
            <div key={cel.z} style={{background:`${t.col}16`,border:`3px solid ${t.col}`,boxShadow:`0 0 18px ${t.col}55, inset 0 -6px 0 ${t.col}22`,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:8}}>
              <div style={{fontFamily:PS,fontSize:30,color:t.col,textShadow:`0 0 14px ${t.col}cc`,letterSpacing:1}}>{cel.z}</div>
              <div style={{fontFamily:PS,fontSize:11,color:'#fff',letterSpacing:1}}>{t.term}</div>
              <div style={{fontFamily:VT,fontSize:17,color:INK+'0.6)',letterSpacing:1}}>{cel.miss?(bull?'NO SCORE':'5 STROKES'):`${cel.stroke} STROKE${cel.stroke>1?'S':''}`}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

const Overlay3=({children})=>(
  <div style={{position:'absolute',inset:0,zIndex:8,display:'flex',alignItems:'center',justifyContent:'center',background:`radial-gradient(ellipse at center, ${RED}22 0%, rgba(5,0,14,0.9) 70%)`,backdropFilter:'blur(2px)'}}>{children}</div>
);

// ── COCKPIT v3 ──────────────────────────────────────────────────
const Cockpit3=({s})=>(
  <Frame3>
    <TopBar3 hole={s.hole} holes={18} playoff={s.playoff}/>
    <Hero3 p={s.active} hole={s.hole} darts={s.darts} lie={s.lie} mode={s.mode} target={s.target} playoff={s.playoff} next={s.next} wash={s.wash}/>
    <Board3 players={s.players} hole={s.hole} playoff={s.playoff}/>
    {s.chain!=null?<Chain3 stage={s.chain}/>:<Strip3 card={s.card} hole={s.hole}/>}
    <div style={{flex:1}}/>
    <Console3 target={s.target!=null&&s.target!=='BULL'?s.target:s.hole} bull={s.target==='BULL'}/>
    {s.overlay==='sudden'&&(
      <Overlay3>
        <div style={{textAlign:'center'}}>
          <div style={{fontSize:46}}>⛳</div>
          <div style={{fontFamily:PS,fontSize:44,color:RED,letterSpacing:2,textShadow:`0 0 24px ${RED}`,marginTop:12,lineHeight:1.15}}>SUDDEN<br/>DEATH</div>
          <div style={{fontFamily:VT,fontSize:26,color:'#fff',letterSpacing:2,marginTop:16}}>TIED AT {s.active.total} STROKES · PLAYOFF</div>
          <div style={{fontFamily:PS,fontSize:13,color:YELLOW,letterSpacing:1,marginTop:14,textShadow:`0 0 8px ${YELLOW}88`}}>19 → 20 → BULL · LOWEST STROKE WINS</div>
          <div style={{fontFamily:VT,fontSize:16,color:INK+'0.4)',letterSpacing:2,marginTop:18}}>TAP TO CONTINUE · AUTO 1s</div>
        </div>
      </Overlay3>
    )}
    <ActionBar3/>
  </Frame3>
);

// ── fixtures ────────────────────────────────────────────────────
const mkCard3=(arr)=>{const c=Array(18).fill(null);arr.forEach((s,i)=>c[i]=s);return c;};
const sum3=(c)=>c.reduce((a,v)=>a+(v||0),0);
const vsp3=(c)=>sum3(c)-PAR*c.filter(v=>v!=null).length;
const META3={JON:['Jonas',CYAN],MIA:['Mia',YELLOW],KAR:['Kari',MAGENTA],PER:['Per',GREEN],OLA:['Ola',ORANGE],EMA:['Emma',CYAN]};
const CARDS7={JON:[3,2,3,1,3,3],MIA:[3,3,2,3,3,2,2],KAR:[3,3,3,3,2,3,3],PER:[3,3,4,3,3,3]};
const CARDS7_SIX={...CARDS7,OLA:[3,3,3,2,3,3],EMA:[3,4,3,3,3,3,3]};
const mkPlayers3=(cards,activeKey,hole,rename)=>Object.keys(cards).map(k=>{
  const [name,accent]=META3[k];
  const c=mkCard3(cards[k]);
  return {handle:k,name:(rename&&k===activeKey)?rename:name,accent,card:c,total:sum3(c),vsPar:vsp3(c),active:k===activeKey,holeStroke:k===activeKey?null:(c[hole-1]??null)};
});
const st3=(cards,activeKey,hole,darts,lie,mode,opts={})=>{
  const players=mkPlayers3(cards,activeKey,hole,opts.rename);
  const active=players.find(p=>p.active);
  return {hole,players,active,card:active.card,darts,lie,mode,next:'PER',...opts};
};
const D_MID=[{z:'S7'},{z:'D7'}];
const WASH_CARD=[3,3,2,3,3,3,3,1,3,3,2,3,3,3,2,3,3];
const S3={
  teeoff: st3(CARDS7,'JON',7,[],null,'teeoff'),
  mid:    st3(CARDS7,'JON',7,D_MID,2,'mid'),
  result: st3(CARDS7,'JON',7,D_MID,2,'result'),
  six:    st3(CARDS7_SIX,'JON',7,D_MID,2,'mid'),
  long:   st3(CARDS7,'JON',7,D_MID,2,'mid',{rename:'Alexander the boss bitch'}),
  hole1:  st3({JON:[],MIA:[],KAR:[],PER:[]},'JON',1,[],null,'teeoff'),
  wash:   st3({...CARDS7,JON:WASH_CARD},'JON',18,[{z:'✗'},{z:'✗'},{z:'✗'}],6,'result',{wash:true,next:'MIA'}),
  sudden: (()=>{const players=mkPlayers3(CARDS7,'JON',18).slice(0,2).map(p=>({...p,total:54,vsPar:0,holeStroke:null}));
    return {hole:18,players,active:{...players[0],total:54,vsPar:0},card:players[0].card,darts:[],lie:null,mode:'teeoff',playoff:true,target:19,chain:0,overlay:'sudden'};})(),
  bull:   (()=>{const players=mkPlayers3(CARDS7,'JON',18).slice(0,2).map(p=>({...p,total:54,vsPar:0,holeStroke:null}));
    return {hole:18,players,active:{...players[0],total:54,vsPar:0},card:players[0].card,darts:[{z:'25'}],lie:2,mode:'mid',playoff:true,target:'BULL',chain:2};})(),
};

// ── SPEC / FASIT CARD ───────────────────────────────────────────
const SRow3=({k,v})=>(
  <div style={{padding:'7px 0',borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{fontFamily:'"Inter",sans-serif',fontSize:12.5,fontWeight:700,color:'#2a251f'}}>{k}</div>
    <div style={{fontFamily:'"Inter",sans-serif',fontSize:11.5,lineHeight:1.45,color:'#5a544a',marginTop:2}}>{v}</div>
  </div>
);
const SpecCard3=()=>(
  <div style={{boxSizing:'border-box',width:680,height:1300,background:'#fffdf6',border:'1.5px solid rgba(0,0,0,0.14)',padding:'30px 34px',fontFamily:'"Inter",system-ui,sans-serif',display:'flex',flexDirection:'column',gap:12,overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono",monospace',fontSize:11,letterSpacing:2,color:'#c96442',textTransform:'uppercase',fontWeight:600,marginBottom:6}}>Golf · overview · mode round 4 · KISS · fasit</div>
      <div style={{fontFamily:'"Archivo","Inter",sans-serif',fontSize:25,fontWeight:900,letterSpacing:-0.5,color:'#2a251f',lineHeight:1.08}}>Hullet opp ved navnet, chips i platen, scroll der lister vokser</div>
    </div>
    <div style={{padding:'11px 14px',background:'#dcefe1',border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"JetBrains Mono",monospace',fontSize:11.5,color:'#2a4a36',lineHeight:1.7}}>
        <b>SONEBUDSJETT @ 820×1180 (regel 2 — ingen state vokser i spill):</b><br/>
        TOPBAR 64 · [14] · HERO 244 · [12] · LEADERBOARD 34+56×min(n,5) ·<br/>
        [12] · STRIP/CHAIN 96 · [flex] · CONSOLE 220 · ACTIONBAR-bånd 100
      </div>
    </div>
    <div>
      <SRow3 k="D1 · Hero: navn + hull på samme linje" v="Regel 4-header (foto-avatar 56, navnkurve 18/15/12/10, pips + «DART n/3») med hullnummeret 120px GRØNT til høyre for navnet. Navnet trunkerer (minWidth 0), tallet flexShrink 0 — langt navn kan aldri dytte hullet. TOTAL utgår av heroen; leaderboardet eier totals."/>
      <SRow3 k="D2 · Dart-chips i platen (P2: misses stack)" v="Tre alltid-rendrede 36px chips i status-platen viser per-dart-historikken (S7 / D7 / ✗ i term-farge, · = ukastet). Ingen ladder, ingen prosa — wash leses som ✗ ✗ ✗."/>
      <SRow3 k="D3 · Status-plate = state-kanalen" v="56px, alltid rendret: tee-off (nøytral, «LAST DART COUNTS») · LYING n + term + m DARTS LEFT (mid) · fylt term-farget plate med NEXT ▸ + progressbar (hole result, 1s). Hero-rammen er spiller-accent og flipper aldri."/>
      <SRow3 k="D4 · Pinnet budsjett, chain i strip-sonen" v="Ingen auto-spacer. Playoff skjuler ikke stripen: samme 96px-sone viser kjeden 19 → 20 → BULL (✓ TIED / ▶ NOW). Ingen soner flytter seg mellom states."/>
      <SRow3 k="D5 · Leaderboard: kompakt (v2-tetthet) · scroll >5" v="56px-rader som i v2 — ingen strukket luft. Spillerantall er konstant i et spill, så høyden er spill-konstant; maks 5 synlige rader (314px), deretter scroll med «▼ n PLAYERS · SCROLL»-hint. THROWING-kolonnen utgår (heroen viser hvem som kaster); accent-bar + tint markerer aktiv rad. Score er helten: TOTAL 24px + ±par 15px farget («10 +1» / «8 −1»). Kolonner: rank · dot · navn · this-hole-chip · score."/>
      <SRow3 k="D6 · YOUR CARD: alle 18, side-scroll" v="72px-celler × 18, horisontal swipe i 96px-sonen; auto-sentrerer gjeldende hull (klemt mot endene). «‹ SWIPE ›»-hint i labelen; SCORECARD ▸ (fullt ark) beholdes."/>
      <SRow3 k="D7 · PROPOSAL: ✗ MISS inn i konsollen" v="MISS er nest mest brukte handling — den løftes inn som fjerde celle i TAP TO SCORE (rød, «MISS · 5 STROKES»; playoff: «NO SCORE»). Registrering av kast samles på ÉN flate. ActionBar er godkjent chrome og står urørt i mockupen — implementation avgjør om ✗ MISS der fjernes eller beholdes som duplikat. Trenger sign-off."/>
    </div>
    <div style={{padding:'11px 14px',background:'#fbe9d8',border:'1px solid rgba(201,100,66,0.35)'}}>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:13,fontWeight:800,color:'#5a442f',marginBottom:4}}>Beholdt fra v2 (QA-godkjent) + tekstkutt</div>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,color:'#5a442f',lineHeight:1.5}}>Nordstjernen: <b>kun konsollen gløder</b> — og nå bor ALL registrering der (S/D/T + ✗). Kuttet (KISS): TOTAL i hero, THROWING-kolonnen, «REGISTERS YOUR STROKE», H-prefiks på chips. Hullnummer 120px (var ~130 — verifiser oche-lesbarhet i QA). TopBar / ActionBar / S/D/T-celler = godkjent chrome.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:13,fontWeight:800,color:'#2a251f',marginBottom:4,textTransform:'uppercase',letterSpacing:0.5}}>Stress-states (alle på artboardet)</div>
      {[
        ['Første dart, hull 1','Tomt kort, tomme chips, alle · , totals 0 E — ingenting kollapser.'],
        ['6 spillere','56px-rader, 5 synlige + scroll; 6. rad kuttes i kanten. Accent-syklusen repeterer (6. = cyan).'],
        ['Langt navn (>16 tegn)','Navnkurve bunner på 10px, trunkerer før hullnummeret; leaderboard midt-kutter til 16.'],
        ['Hull 18 wash (6 strokes)','Chips ✗ ✗ ✗, plate fylt rød «LYING 6 · TRIPLE BOGEY · WASH», kortet scrollet til slutten.'],
        ['Sudden death','Rødt overlay (tap/1s), kjeden 19 ▶ NOW, konsoll S19/D19/T19.'],
        ['Playoff BULL','Kjeden 19 ✓ 20 ✓ BULL ▶ · celler 25/50/✗ · leaderboard = tied leaders, kompakt.'],
      ].map(([t,b])=><SRow3 key={t} k={t} v={b}/>)}
    </div>
    <div style={{marginTop:'auto',padding:'11px 14px',background:'#f4f0e8',border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter",sans-serif',fontSize:12,lineHeight:1.5,color:'#2a251f'}}><b>Implementation owns:</b> regler/scoring/sudden death, per-dart-historikkdata (sone per kast), scroll-fysikk + auto-sentrering (leaderboard/kort), widget-omskrivinger, fixed-height-regresjonstest som pinner sonebudsjettet. <b>Tokens only</b> · Press Start 2P / VT323 · no border-radius · engelske strings · grønn = Golf-brand.</div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const GolfOverviewRound=()=>(
  <React.Fragment>
    <DCSection id="g3-compare" title="Dagens v2 vs forslag v3 (KISS) — samme data, tre states"
      subtitle="v2-skjelettet står, men mindre skjer: hullnummeret ved navnet i én header, dart-historikken som tre chips i platen, leaderboard i v2-tetthet der score + ±par er helten (THROWING utgår — heroen viser hvem som kaster), YOUR CARD side-scroller alle 18 hull, og ✗ MISS er løftet inn i konsollen som fjerde celle (PROPOSAL).">
      <DCArtboard id="g3-v2-tee" label="I DAG (v2) · tee off" width={W} height={H}><window.V2Cockpit s={window.V2_STATES.teeoff}/></DCArtboard>
      <DCArtboard id="g3-v3-tee" label="FORSLAG (v3) · tee off" width={W} height={H}><Cockpit3 s={S3.teeoff}/></DCArtboard>
      <DCArtboard id="g3-v2-mid" label="I DAG (v2) · mid-hole" width={W} height={H}><window.V2Cockpit s={window.V2_STATES.mid}/></DCArtboard>
      <DCArtboard id="g3-v3-mid" label="FORSLAG (v3) · mid-hole" width={W} height={H}><Cockpit3 s={S3.mid}/></DCArtboard>
      <DCArtboard id="g3-v2-res" label="I DAG (v2) · hole result" width={W} height={H}><window.V2Cockpit s={window.V2_STATES.result}/></DCArtboard>
      <DCArtboard id="g3-v3-res" label="FORSLAG (v3) · hole result" width={W} height={H}><Cockpit3 s={S3.result}/></DCArtboard>
    </DCSection>
    <DCSection id="g3-stress" title="v3 — stress-states (brief-listen)"
      subtitle="Første dart hull 1 · 6 spillere (scroll) · langt navn · hull 18 wash · sudden death · playoff BULL. Samme pinnede sonebudsjett i alle — playoff fyller strip-sonen med kjeden.">
      <DCArtboard id="g3-s1" label="Første dart · hull 1" width={W} height={H}><Cockpit3 s={S3.hole1}/></DCArtboard>
      <DCArtboard id="g3-s2" label="6 spillere · leaderboard scroller" width={W} height={H}><Cockpit3 s={S3.six}/></DCArtboard>
      <DCArtboard id="g3-s3" label="Langt navn (24 tegn)" width={W} height={H}><Cockpit3 s={S3.long}/></DCArtboard>
      <DCArtboard id="g3-s4" label="Hull 18 · wash (LYING 6)" width={W} height={H}><Cockpit3 s={S3.wash}/></DCArtboard>
      <DCArtboard id="g3-s5" label="Sudden death · overlay + target 19" width={W} height={H}><Cockpit3 s={S3.sudden}/></DCArtboard>
      <DCArtboard id="g3-s6" label="Playoff · BULL · 25/50/✗" width={W} height={H}><Cockpit3 s={S3.bull}/></DCArtboard>
    </DCSection>
    <DCSection id="g3-spec" title="Golf overview — fasit"
      subtitle="Sonebudsjettet i px, de seks deltaene mot v2, tekstkuttene, og hva implementation eier.">
      <DCArtboard id="g3-spec-card" label="Spec · Golf mode round 4" width={680} height={1300}><SpecCard3/></DCArtboard>
    </DCSection>
  </React.Fragment>
);
window.GolfOverviewRound=GolfOverviewRound;
