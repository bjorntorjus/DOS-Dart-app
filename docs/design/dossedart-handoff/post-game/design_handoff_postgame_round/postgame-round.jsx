// DOSSEDART — Post-game screen round (2026-08-10)
// Responds to HANDOVER-to-design-2026-08-10-post-game-brief.md
// Decisions (user-picked): spotlight winner · fixed label/value stat grid ·
// all placements equal + compact · conditional fields dim in place with "—" ·
// match summary at the bottom, under placements + chart.
const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', PURPLE='#B15CFF', LIME='#C6FF3C',
      SILVER='#C0C0C0', BG='#0a0014', SURFACE='#1a0030';
const INK='rgba(255,255,255,';
const PS='"Press Start 2P", monospace';
const VT='"VT323", monospace';
const W=820, H=1180, TOPBAR=52, HERO=196, ACTIONS=134;
const SCROLL=H-TOPBAR-HERO-ACTIONS; // 798
const CYCLE=[CYAN,MAGENTA,GREEN,PURPLE,ORANGE]; // 5-accent cycle (rule 7)
const nameSize=(n)=>n.length<=8?14:n.length<=12?12:n.length<=16?10:9;
const heroName=(n)=>n.length<=8?26:n.length<=12?21:n.length<=16?17:13;

// ── demo data ───────────────────────────────────────────────────
// f(label,value) — a stat cell. fz() = conditional field resolved to zero:
// rendered, dimmed, value "—" (never removed; never reflows the grid).
const f=(label,value)=>({label,value});
const fz=(label)=>({label,value:'—',zero:true});
const P=(place,name,handle,ai,headline,fields,elo,o={})=>
  ({place,name,handle,accent:CYCLE[ai%5],headline,fields,elo,...o});

const X01=[
  P(1,'Jonas','JON',0,['3-DART AVG','62.4'],[f('BEST','140'),f('DARTS','24'),f('CHECKOUT','D20'),f('100+ / 140+ / 180','7 / 2 / 1'),f('CHECKOUT %','33%'),f('FIRST-9','71.2')],12.3,{you:true}),
  P(2,'Andreas','AND',1,['3-DART AVG','55.1'],[f('BEST','121'),f('DARTS','27'),fz('CHECKOUT'),f('100+ / 140+ / 180','4 / 1 / 0'),f('CHECKOUT %','0%'),f('FIRST-9','60.8')],3.1),
  P(3,'Mia','MIA',2,['3-DART AVG','41.8'],[f('BEST','100'),f('DARTS','33'),fz('CHECKOUT'),f('100+ / 140+ / 180','1 / 0 / 0'),f('CHECKOUT %','0%'),f('FIRST-9','48.3')],-8.4),
];
const X01_6=[
  ...X01,
  P(4,'Per','PER',3,['3-DART AVG','39.2'],[f('BEST','95'),f('DARTS','36'),fz('CHECKOUT'),f('100+ / 140+ / 180','0 / 0 / 0'),f('CHECKOUT %','0%'),f('FIRST-9','44.1')],-2.6),
  P(5,'Tor','TOR',4,['3-DART AVG','36.7'],[f('BEST','85'),f('DARTS','39'),fz('CHECKOUT'),f('100+ / 140+ / 180','0 / 0 / 0'),f('CHECKOUT %','0%'),f('FIRST-9','41.9')],-1.9),
  P(6,'Kari','KAR',0,['3-DART AVG','30.5'],[f('BEST','60'),f('DARTS','42'),fz('CHECKOUT'),f('100+ / 140+ / 180','0 / 0 / 0'),f('CHECKOUT %','0%'),f('FIRST-9','33.4')],-2.5),
];
const SPLIT=[
  P(1,'Kari','KAR',1,['SCORE','480'],[f('HALVED','2'),f('HALVING LOSSES','240')],9.8),
  P(2,'Jonas','JON',0,['SCORE','300'],[f('HALVED','3'),f('HALVING LOSSES','420')],-4.1,{you:true}),
  P(3,'Per','PER',2,['SCORE','120'],[f('HALVED','4'),f('HALVING LOSSES','600')],-5.7),
];
const GOLF=[
  P(1,'Mia','MIA',2,['STROKES','54 (+3)'],[f('ACES','1'),f('BOGEYS','4'),f('BEST HOLE','2'),f('1ST-DART','7/18'),f('TERMS','A1 B4 P9 B+4')],11.2),
  P(2,'Jonas','JON',0,['STROKES','58 (+7)'],[f('ACES','0'),f('BOGEYS','6'),f('BEST HOLE','1'),f('1ST-DART','5/18'),f('TERMS','A0 B6 P8 B+4')],2.4,{you:true}),
  P(3,'Andreas','AND',1,['STROKES','66 (+15)'],[f('ACES','0'),f('BOGEYS','9'),f('BEST HOLE','2'),f('1ST-DART','3/18'),f('TERMS','A0 B9 P6 B+3')],-13.6),
];
const TIE=[
  P(1,'Jonas','JON',0,['3-DART AVG','62.4'],X01[0].fields,12.3,{you:true}),
  P(2,'Andreas','AND',1,['3-DART AVG','55.1'],X01[1].fields,1.5,{tie:true}),
  P(2,'Mia','MIA',2,['3-DART AVG','55.1'],X01[2].fields,1.5,{tie:true}),
];
const LONG=[
  P(1,'Alexander the boss bitch','ALE',1,['3-DART AVG','62.4'],X01[0].fields,12.3),
  P(2,'Jonas','JON',0,['3-DART AVG','55.1'],X01[1].fields,3.1,{you:true}),
  P(3,'Christopher Nordbø-Hansen','CHR',2,['3-DART AVG','41.8'],X01[2].fields,-8.4),
];
const WILD=[
  P(1,'Per','PER',2,['SCORE','412'],[f('JOKERS','3'),f('PRIZES','2'),fz('STOLEN'),f('BEST','96'),f('DARTS','27'),f('CHAOS PEAK','×4')],null),
  P(2,'Jonas','JON',0,['SCORE','388'],[f('JOKERS','2'),f('PRIZES','1'),f('STOLEN','60'),f('BEST','81'),f('DARTS','27'),f('CHAOS PEAK','×3')],null,{you:true}),
  P(3,'Kari','KAR',1,['SCORE','204'],[f('JOKERS','1'),fz('PRIZES'),fz('STOLEN'),f('BEST','60'),f('DARTS','27'),f('CHAOS PEAK','×2')],null),
];

const SUMMARY={duration:'18:42',rounds:'14',darts:'168',bestTurn:'140',bestBy:'JONAS · R7',
  hits:'T 14 · D 22 · B 3 · ✗ 41',lead:'118'};
const SUMMARY_DEGRADED={duration:'18:42'};

// ── primitives ──────────────────────────────────────────────────
const scan='repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)';
const Avatar=({size,handle,accent})=>(
  <div style={{width:size,height:size,flexShrink:0,border:`${size>=64?3:2}px solid ${accent}`,position:'relative',boxShadow:`0 0 ${size>=64?18:10}px ${accent}55`,
    background:'repeating-linear-gradient(135deg, #1c0033 0, #1c0033 4px, #130024 4px, #130024 8px)',display:'flex',alignItems:'center',justifyContent:'center'}}>
    <span style={{fontFamily:VT,fontSize:size*0.4,color:INK+'0.42)',letterSpacing:1}}>{handle}</span>
    {size>=44&&<span style={{position:'absolute',bottom:2,right:3,fontFamily:VT,fontSize:9,color:INK+'0.28)'}}>▨</span>}
  </div>
);
const medal=(place)=>place===1?YELLOW:place===2?SILVER:place===3?ORANGE:null;
const Elo=({d})=>{
  if(d===null)return(
    <div style={{width:86,textAlign:'right',opacity:0.3}}>
      <div style={{fontFamily:VT,fontSize:14,color:INK+'0.6)',letterSpacing:2}}>ELO</div>
      <div style={{fontFamily:PS,fontSize:11,color:'#fff',marginTop:4}}>—</div>
    </div>);
  const up=d>0,c=up?GREEN:d<0?RED:INK+'0.5)';
  return(
    <div style={{width:86,textAlign:'right'}}>
      <div style={{fontFamily:VT,fontSize:14,color:INK+'0.42)',letterSpacing:2}}>ELO</div>
      <div style={{fontFamily:PS,fontSize:11,color:c,textShadow:`0 0 7px ${c}88`,marginTop:4}}>{up?'▲':d<0?'▼':'='}{d>0?'+':''}{d.toFixed(1)}</div>
    </div>);
};
const Ruler=({label,top,height,color=YELLOW})=>(
  <div style={{position:'absolute',top,height,right:2,width:13,borderTop:`1px solid ${color}99`,borderBottom:`1px solid ${color}99`,borderRight:`1px solid ${color}99`,zIndex:9,pointerEvents:'none'}}>
    <span style={{position:'absolute',top:'50%',right:1,transform:'translateY(-50%)',writingMode:'vertical-rl',fontFamily:PS,fontSize:6,color,letterSpacing:1,whiteSpace:'nowrap'}}>{label}</span>
  </div>
);

// ── chrome ──────────────────────────────────────────────────────
const TopBar=({mode})=>(
  <div style={{height:TOPBAR,boxSizing:'border-box',padding:'0 22px',background:'#000',borderBottom:`2px solid ${MAGENTA}`,display:'flex',alignItems:'center',gap:14,position:'relative',zIndex:6,flexShrink:0}}>
    <div style={{width:120,fontFamily:VT,fontSize:18,color:INK+'0.5)',letterSpacing:2}}>{mode}</div>
    <div style={{flex:1,textAlign:'center',fontFamily:PS,fontSize:13,color:YELLOW,letterSpacing:3,textShadow:`0 0 10px ${YELLOW}99`}}>GAME OVER</div>
    <div style={{width:120,textAlign:'right',fontFamily:VT,fontSize:17,color:INK+'0.5)',letterSpacing:2}}>{SUMMARY.duration}</div>
  </div>
);
const Btn=({label,color,flex,primary,off})=>(
  <div style={{flex,boxSizing:'border-box',padding:'14px 6px',textAlign:'center',opacity:off?0.28:1,
    background:primary?color:'transparent',border:`2px solid ${primary?'#fff':color}`,
    fontFamily:PS,fontSize:primary?12:10,letterSpacing:primary?2:1,color:primary?BG:color,
    boxShadow:primary?`0 0 18px ${color}8c`:'none'}}>{label}</div>
);
const ActionBar=({noDetails})=>(
  <div style={{height:ACTIONS,boxSizing:'border-box',padding:'12px 16px 16px',background:'#000',borderTop:`2px solid ${YELLOW}`,display:'flex',flexDirection:'column',gap:9,position:'relative',zIndex:6,flexShrink:0}}>
    <div style={{display:'flex',gap:9}}>
      <Btn label="↶ BACK" color={MAGENTA} flex={1}/>
      <Btn label="▶ CONTINUE" color={CYAN} flex={1.25}/>
      <Btn label="▶ DETAILS" color={PURPLE} flex={1.25} off={noDetails}/>
    </div>
    <Btn label="✓ FINISH GAME" color={LIME} flex="none" primary/>
  </div>
);

// ── winner spotlight (P1) ───────────────────────────────────────
const Plate=({label,value,color})=>(
  <div style={{boxSizing:'border-box',minWidth:150,padding:'8px 14px',border:`2px solid ${color}`,background:`${color}12`,textAlign:'right'}}>
    <div style={{fontFamily:VT,fontSize:15,color:INK+'0.55)',letterSpacing:2}}>{label}</div>
    <div style={{fontFamily:PS,fontSize:18,color,textShadow:`0 0 12px ${color}aa`,marginTop:6}}>{value}</div>
  </div>
);
const Hero=({w})=>(
  <div style={{height:HERO,boxSizing:'border-box',flexShrink:0,position:'relative',padding:'0 22px',display:'flex',alignItems:'center',gap:22,
    background:`radial-gradient(ellipse at 24% 40%, ${YELLOW}1f 0%, transparent 62%)`,borderBottom:`1px solid ${MAGENTA}44`}}>
    <div style={{position:'absolute',inset:0,pointerEvents:'none',background:`linear-gradient(90deg, ${YELLOW}0a, transparent 55%)`}}></div>
    <div style={{position:'relative'}}>
      <Avatar size={104} handle={w.handle} accent={YELLOW}/>
      <div style={{position:'absolute',top:-14,left:'50%',transform:'translateX(-50%)',fontSize:26,lineHeight:1,filter:`drop-shadow(0 0 8px ${YELLOW})`}}>👑</div>
    </div>
    <div style={{flex:1,minWidth:0}}>
      <div style={{fontFamily:PS,fontSize:11,color:YELLOW,letterSpacing:4,textShadow:`0 0 10px ${YELLOW}aa`}}>★ WINNER ★</div>
      <div style={{fontFamily:PS,fontSize:heroName(w.name),color:'#fff',letterSpacing:1.5,lineHeight:1.25,marginTop:12,textShadow:`0 0 16px ${YELLOW}55`,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{w.name.toUpperCase()}</div>
      <div style={{fontFamily:VT,fontSize:19,color:INK+'0.5)',letterSpacing:2,marginTop:10}}>{w.headline[0]} {w.headline[1]}</div>
    </div>
    <div style={{display:'flex',flexDirection:'column',gap:9,flexShrink:0}}>
      <Plate label={w.headline[0]} value={w.headline[1]} color={YELLOW}/>
      <Plate label="ELO" value={w.elo===null?'—':`${w.elo>0?'+':''}${w.elo.toFixed(1)}`} color={w.elo===null?'#6a5f7a':GREEN}/>
    </div>
  </div>
);

// ── placement card + the stat grid (P2 — the wall-of-text fix) ──
// Rule: headline never enters the grid. Grid = 3 fixed columns, cells filled
// in the mode's declared order, rows = ceil(fields/3), trailing slots render
// as empty dim tracks. Nothing reflows between games.
const StatCell=({c})=>{
  if(!c)return <div style={{height:34,border:`1px solid ${MAGENTA}18`,background:'rgba(255,255,255,0.012)'}}></div>;
  return(
    <div style={{height:34,boxSizing:'border-box',border:`1px solid ${MAGENTA}33`,background:'rgba(255,255,255,0.025)',padding:'0 10px',display:'flex',alignItems:'center',justifyContent:'space-between',gap:8,opacity:c.zero?0.34:1}}>
      <span style={{fontFamily:VT,fontSize:15,color:INK+'0.5)',letterSpacing:1,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{c.label}</span>
      <span style={{fontFamily:PS,fontSize:10,color:'#fff',letterSpacing:0.5,whiteSpace:'nowrap',flexShrink:0}}>{c.value}</span>
    </div>);
};
const StatGrid=({fields})=>{
  const rows=Math.ceil(fields.length/3),slots=[...fields];
  while(slots.length<rows*3)slots.push(null);
  return(
    <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:6,marginTop:9}}>
      {slots.map((c,i)=><StatCell key={i} c={c}/>)}
    </div>);
};
const Placement=({p})=>{
  const m=medal(p.place),c=p.accent;
  return(
    <div style={{boxSizing:'border-box',padding:'11px 12px 12px',background:SURFACE,
      border:`2px solid ${p.place===1?YELLOW:c+'88'}`,boxShadow:p.place===1?`0 0 14px ${YELLOW}44`:'none'}}>
      <div style={{display:'flex',alignItems:'center',gap:12}}>
        <div style={{width:38,height:38,flexShrink:0,border:`2px solid ${m||INK+'0.3)'}`,background:m?`${m}18`:'transparent',display:'flex',alignItems:'center',justifyContent:'center',
          fontFamily:PS,fontSize:14,color:m||INK+'0.7)',textShadow:m?`0 0 8px ${m}aa`:'none'}}>{p.place}</div>
        <Avatar size={40} handle={p.handle} accent={c}/>
        <div style={{flex:1,minWidth:0}}>
          <div style={{display:'flex',alignItems:'center',gap:8}}>
            <span style={{fontFamily:PS,fontSize:nameSize(p.name),color:'#fff',letterSpacing:1,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{p.name.toUpperCase()}</span>
            {p.you&&<span style={{fontFamily:PS,fontSize:7,color:c,border:`1px solid ${c}`,padding:'2px 4px',letterSpacing:1,flexShrink:0}}>YOU</span>}
            {p.tie&&<span style={{fontFamily:VT,fontSize:15,color:YELLOW,letterSpacing:1,flexShrink:0}}>TIED</span>}
          </div>
          <div style={{fontFamily:VT,fontSize:15,color:INK+'0.45)',letterSpacing:1.5,marginTop:5}}>{p.headline[0]}</div>
        </div>
        <div style={{fontFamily:PS,fontSize:20,color:c,textShadow:`0 0 12px ${c}aa`,letterSpacing:-0.5,flexShrink:0}}>{p.headline[1]}</div>
        <Elo d={p.elo}/>
      </div>
      <StatGrid fields={p.fields}/>
    </div>
  );
};

// ── reused widgets (place, do not redesign) ─────────────────────
const SectionLabel=({children,note})=>(
  <div style={{display:'flex',alignItems:'baseline',gap:10,margin:'0 0 9px'}}>
    <span style={{fontFamily:PS,fontSize:9,color:INK+'0.5)',letterSpacing:2}}>{children}</span>
    {note&&<span style={{fontFamily:VT,fontSize:15,color:INK+'0.32)',letterSpacing:1}}>{note}</span>}
  </div>
);
const ProgressionChart=({players,h=168})=>(
  <div style={{height:h,boxSizing:'border-box',border:`1px solid ${MAGENTA}44`,background:'rgba(255,255,255,0.018)',position:'relative',overflow:'hidden'}}>
    <svg width="100%" height="100%" viewBox="0 0 760 168" preserveAspectRatio="none" style={{display:'block'}}>
      {[42,84,126].map(y=><line key={y} x1="0" y1={y} x2="760" y2={y} stroke={MAGENTA} strokeOpacity="0.16"/>)}
      {players.map((p,i)=>{
        const j=[0,7,4,11,6,13,9,15][i%8];
        const pts=[0,1,2,3,4,5,6,7].map(k=>{
          const g=(k*(19-i*3.4))+((k*7+j)%5)*4;
          return `${k*108.5},${Math.max(12,152-g-i*4)}`;
        }).join(' ');
        return <polyline key={i} points={pts} fill="none" stroke={p.accent} strokeWidth="2.5" opacity="0.95"/>;
      })}
    </svg>
    <span style={{position:'absolute',bottom:5,right:8,fontFamily:VT,fontSize:13,color:INK+'0.3)',letterSpacing:1}}>ProgressionChart · reused verbatim</span>
  </div>
);
const GolfScoreGrid=()=>{
  const holes=[1,2,3,4,5,6,7,8,9,10];
  const rows=[['MIA',PURPLE,[3,1,4,2,3,5,2,3,4,3]],['JONAS',CYAN,[4,3,3,5,2,4,3,4,3,4]],['ANDREAS',MAGENTA,[5,4,6,3,4,6,3,5,4,5]]];
  return(
    <div style={{border:`1px solid ${MAGENTA}44`,background:'rgba(255,255,255,0.018)',position:'relative',overflow:'hidden'}}>
      <div style={{display:'grid',gridTemplateColumns:`88px repeat(${holes.length}, 1fr) 34px`,alignItems:'center'}}>
        <div style={{fontFamily:PS,fontSize:7,color:INK+'0.4)',padding:'8px 6px',letterSpacing:1}}>HOLE</div>
        {holes.map(h=><div key={h} style={{textAlign:'center',fontFamily:PS,fontSize:8,color:INK+'0.55)',padding:'8px 0'}}>{h}</div>)}
        <div style={{textAlign:'center',fontFamily:VT,fontSize:16,color:INK+'0.3)'}}>›</div>
        {rows.map(([n,c,vals])=>(<React.Fragment key={n}>
          <div style={{fontFamily:PS,fontSize:8,color:c,padding:'9px 6px',borderTop:`1px solid ${MAGENTA}22`,letterSpacing:0.5,whiteSpace:'nowrap',overflow:'hidden'}}>{n}</div>
          {vals.map((v,i)=><div key={i} style={{textAlign:'center',fontFamily:PS,fontSize:10,color:v<=1?YELLOW:v>=5?RED:'#fff',padding:'9px 0',borderTop:`1px solid ${MAGENTA}22`,textShadow:v<=1?`0 0 8px ${YELLOW}aa`:'none'}}>{v}</div>)}
          <div style={{borderTop:`1px solid ${MAGENTA}22`}}></div>
        </React.Fragment>))}
      </div>
      <div style={{position:'absolute',top:0,bottom:0,right:0,width:34,background:`linear-gradient(90deg, transparent, ${BG})`,pointerEvents:'none'}}></div>
    </div>
  );
};

// ── match summary (new zone, P2) — bottom of the scroll ─────────
const SumCell=({label,value,sub,dim,wide})=>(
  <div style={{gridColumn:wide?'span 2':'span 1',boxSizing:'border-box',padding:'9px 11px',border:`1px solid ${MAGENTA}33`,background:'rgba(255,255,255,0.025)',opacity:dim?0.32:1}}>
    <div style={{fontFamily:VT,fontSize:14,color:INK+'0.5)',letterSpacing:1.5,whiteSpace:'nowrap'}}>{label}</div>
    <div style={{fontFamily:PS,fontSize:13,color:dim?'#fff':LIME,textShadow:dim?'none':`0 0 9px ${LIME}66`,marginTop:7,whiteSpace:'nowrap'}}>{value}</div>
    {sub&&<div style={{fontFamily:VT,fontSize:14,color:INK+'0.42)',letterSpacing:1,marginTop:4}}>{sub}</div>}
  </div>
);
const MatchSummary=({data,degraded})=>(
  <div>
    <SectionLabel note={degraded?'· partly unavailable':null}>MATCH SUMMARY</SectionLabel>
    <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:6}}>
      <SumCell label="DURATION" value={data.duration}/>
      <SumCell label="ROUNDS" value={degraded?'—':data.rounds} dim={degraded}/>
      <SumCell label="DARTS THROWN" value={degraded?'—':data.darts} dim={degraded}/>
      <SumCell label="BEST TURN" value={degraded?'—':data.bestTurn} sub={degraded?'NOT RECORDED':data.bestBy} dim={degraded}/>
      <SumCell label="HIT DISTRIBUTION" value={degraded?'—':data.hits} dim={degraded}/>
      <SumCell label="BIGGEST LEAD" value={degraded?'—':data.lead} dim={degraded}/>
    </div>
  </div>
);
const Notice=()=>(
  <div style={{display:'flex',alignItems:'center',gap:11,padding:'11px 13px',border:`2px solid ${ORANGE}`,background:`${ORANGE}12`}}>
    <span style={{fontFamily:PS,fontSize:14,color:ORANGE,textShadow:`0 0 8px ${ORANGE}aa`}}>!</span>
    <span style={{fontFamily:VT,fontSize:18,color:ORANGE,letterSpacing:1,lineHeight:1.2}}>STATISTICS NOT RECORDED — PLAYER LIST CHANGED MID-GAME</span>
  </div>
);

// ── the screen ──────────────────────────────────────────────────
const Screen=({mode,players,scroll=0,golf,notice,noChart,noDetails,summary=SUMMARY,degraded,rulers})=>{
  const w=players[0];
  return(
    <div style={{width:W,height:H,background:BG,color:'#fff',fontFamily:PS,display:'flex',flexDirection:'column',overflow:'hidden',position:'relative'}}>
      <div style={{position:'absolute',inset:0,backgroundImage:scan,pointerEvents:'none',zIndex:8}}></div>
      <TopBar mode={mode}/>
      <Hero w={w}/>
      <div style={{height:SCROLL,overflow:'hidden',position:'relative',flexShrink:0}}>
        <div style={{position:'absolute',left:0,right:0,...(scroll==='bottom'?{bottom:0}:{top:-scroll}),padding:'14px 14px 20px',display:'flex',flexDirection:'column',gap:16}}>
          {notice&&<Notice/>}
          <div>
            <SectionLabel note={`· ${players.length} players`}>FINAL STANDINGS</SectionLabel>
            <div style={{display:'flex',flexDirection:'column',gap:8}}>
              {players.map((p,i)=><Placement key={i} p={p}/>)}
            </div>
          </div>
          {golf&&<div><SectionLabel note="· 18 holes · swipe">SCORECARD</SectionLabel><GolfScoreGrid/></div>}
          {!noChart&&<div><SectionLabel>SCORE PER ROUND</SectionLabel><ProgressionChart players={players}/></div>}
          <MatchSummary data={summary} degraded={degraded}/>
        </div>
        <div style={{position:'absolute',top:0,right:0,bottom:0,width:3,background:'rgba(255,255,255,0.05)'}}>
          <div style={{position:'absolute',...(scroll?{bottom:0}:{top:0}),height:'44%',left:0,right:0,background:MAGENTA,opacity:0.55}}></div>
        </div>
      </div>
      <ActionBar noDetails={noDetails}/>
      {rulers&&<>
        <Ruler label="TOPBAR 52" top={0} height={TOPBAR} color={CYAN}/>
        <Ruler label="WINNER 196" top={TOPBAR} height={HERO}/>
        <Ruler label="SCROLL 798" top={TOPBAR+HERO} height={SCROLL} color={LIME}/>
        <Ruler label="ACTIONS 134" top={TOPBAR+HERO+SCROLL} height={ACTIONS} color={CYAN}/>
      </>}
    </div>
  );
};

// ── today: classic Material (the thing we are replacing) ────────
const MatCard=({place,name,stat,elo})=>(
  <div style={{background:'#211E26',borderRadius:12,padding:'14px 16px',display:'flex',alignItems:'center',gap:14}}>
    <div style={{width:28,height:28,borderRadius:'50%',background:'#4A4458',color:'#E8DEF8',display:'flex',alignItems:'center',justifyContent:'center',fontFamily:'"Inter", sans-serif',fontSize:14,fontWeight:700}}>{place}</div>
    <div style={{width:36,height:36,borderRadius:'50%',background:'#4A4458'}}></div>
    <div style={{flex:1,minWidth:0}}>
      <div style={{fontFamily:'"Inter", sans-serif',fontSize:16,fontWeight:600,color:'#E6E0E9'}}>{name}</div>
      <div style={{fontFamily:'"Inter", sans-serif',fontSize:12,color:'#E6E0E9',opacity:0.7,marginTop:3,whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{stat}</div>
    </div>
    <div style={{fontFamily:'"Inter", sans-serif',fontSize:13,fontWeight:600,color:elo>0?'#7ED9A0':'#F2B8B5'}}>{elo>0?'+':''}{elo}</div>
  </div>
);
const Today=()=>(
  <div style={{width:W,height:H,background:'#141218',color:'#E6E0E9',display:'flex',flexDirection:'column',overflow:'hidden',position:'relative'}}>
    <div style={{padding:'18px 20px',background:'#211E26',fontFamily:'"Inter", sans-serif',fontSize:22,fontWeight:500}}>Game Over</div>
    <div style={{margin:'16px 16px 0',borderRadius:16,padding:'22px 18px',background:'linear-gradient(160deg, #4A4458 0%, #211E26 100%)',display:'flex',flexDirection:'column',alignItems:'center',gap:8}}>
      <div style={{fontSize:40}}>🏆</div>
      <div style={{width:36,height:36,borderRadius:'50%',background:'#6750A4'}}></div>
      <div style={{fontFamily:'"Inter", sans-serif',fontSize:24,fontWeight:600}}>Mia</div>
      <div style={{fontFamily:'"Inter", sans-serif',fontSize:14,opacity:0.75}}>Winner!</div>
    </div>
    <div style={{margin:'16px 16px 0',borderRadius:12,background:'#211E26',padding:12}}>
      <div style={{fontFamily:'"Inter", sans-serif',fontSize:12,opacity:0.6,marginBottom:8}}>Scorecard</div>
      <div style={{display:'grid',gridTemplateColumns:'repeat(10, 1fr)',gap:4}}>
        {Array.from({length:30}).map((_,i)=><div key={i} style={{height:22,borderRadius:4,background:'#2B2830'}}></div>)}
      </div>
    </div>
    <div style={{margin:'16px 16px 0',display:'flex',flexDirection:'column',gap:10}}>
      <MatCard place={1} name="Mia" stat="Strokes: 54 (+3) | Aces: 1 | Bogeys: 4 | Best hole: 2 | 1st-dart: 7/18 | Terms: A1 B4 P9 B+4" elo={11.2}/>
      <MatCard place={2} name="Jonas" stat="Strokes: 58 (+7) | Aces: 0 | Bogeys: 6 | Best hole: 1 | 1st-dart: 5/18 | Terms: A0 B6 P8 B+4" elo={2.4}/>
      <MatCard place={3} name="Andreas" stat="Strokes: 66 (+15) | Aces: 0 | Bogeys: 9 | Best hole: 2 | 1st-dart: 3/18 | Terms: A0 B9 P6 B+3" elo={-13.6}/>
      <div style={{borderRadius:12,background:'#211E26',padding:14}}>
        <div style={{fontFamily:'"Inter", sans-serif',fontSize:12,opacity:0.6,marginBottom:10}}>SCORE PER ROUND</div>
        <div style={{height:120,borderRadius:8,background:'#2B2830'}}></div>
      </div>
    </div>
    <div style={{marginTop:'auto',padding:16,display:'flex',flexDirection:'column',gap:10}}>
      <div style={{display:'flex',gap:10}}>
        <div style={{flex:1,padding:'13px 0',borderRadius:100,border:'1px solid #938F99',textAlign:'center',fontFamily:'"Inter", sans-serif',fontSize:14}}>↶ Back</div>
        <div style={{flex:1,padding:'13px 0',borderRadius:100,border:'1px solid #938F99',textAlign:'center',fontFamily:'"Inter", sans-serif',fontSize:14}}>▶ Continue</div>
      </div>
      <div style={{padding:'13px 0',borderRadius:100,border:'1px solid #938F99',textAlign:'center',fontFamily:'"Inter", sans-serif',fontSize:14}}>▶ DETAILS</div>
      <div style={{padding:'14px 0',borderRadius:100,background:'#6750A4',textAlign:'center',fontFamily:'"Inter", sans-serif',fontSize:15,fontWeight:600,color:'#fff'}}>Finish Game</div>
    </div>
    <Annotation top={272} left={196} width={200}>Material gradient box + rounded corners — the only non-DOSSEDART surface left in the app</Annotation>
    <Annotation top={620} left={70} width={300}>One joined string at 12px / 70% opacity. Six numbers, no ranking, nothing scannable. This is the core problem.</Annotation>
    <Annotation top={1010} left={430} width={210}>Four buttons in three stacked rows — 190px of the vertical budget</Annotation>
  </div>
);

window.PostgameRound=()=>(<>
  <DCSection id="pg-today" title="1 · Today" subtitle="The classic Material PostGameScreen, shown with Golf (the heaviest stat load). AppBar, Cards, rounded corners, tonal gradient — and the per-player stats joined into one 12px string.">
    <DCArtboard id="pg-today-a" label="Today · Golf · Material" width={W} height={H}><Today/></DCArtboard>
  </DCSection>

  <DCSection id="pg-chosen" title="2 · The design — X01, wave-2 set (the everyday case)" subtitle="Arcade chrome, spotlight winner, and the stat wall replaced by a fixed 3-column label/value grid under every player. Pinned: TopBar · winner · action bar. Scrolls: standings → chart → match summary. At three players the whole screen is 904 px of content in a 798 px region — a 106 px scroll, so the everyday case is almost entirely visible at rest.">
    <DCArtboard id="pg-x01-top" label="X01 · top of screen · zone budget" width={W} height={H}><Screen mode="X01 · 501" players={X01} rulers/></DCArtboard>
    <DCArtboard id="pg-x01-bot" label="X01 · scrolled to the end (106 px)" width={W} height={H}><Screen mode="X01 · 501" players={X01} scroll="bottom"/></DCArtboard>
  </DCSection>

  <DCSection id="pg-loads" title="3 · The three loads" subtitle="Same widget, three field counts. Light = Splitscore: 3 fields, one grid row, 772 px of content — the screen fills without scrolling and without padding. Heavy = Golf: 6 fields + the 18-hole scorecard + the chart, 1063 px, shown top and scrolled to the end.">
    <DCArtboard id="pg-split" label="Light · Splitscore · 3 fields" width={W} height={H}><Screen mode="SPLITSCORE" players={SPLIT} scroll={0}/></DCArtboard>
    <DCArtboard id="pg-golf-top" label="Heavy · Golf · top" width={W} height={H}><Screen mode="GOLF · 18" players={GOLF} golf/></DCArtboard>
    <DCArtboard id="pg-golf-bot" label="Heavy · Golf · scrolled — scorecard + chart + summary" width={W} height={H}><Screen mode="GOLF · 18" players={GOLF} golf scroll="bottom"/></DCArtboard>
  </DCSection>

  <DCSection id="pg-stress" title="4 · Stress states" subtitle="Six players (1390 px of content, top and end) · a 24-character name in both the winner moment and the standings · a shared 2nd place · roster changed mid-game (notice, no chart, DETAILS disabled, match zone degraded) · Wildcard, where no player is rated at all.">
    <DCArtboard id="pg-6" label="6 players · top" width={W} height={H}><Screen mode="X01 · 501" players={X01_6}/></DCArtboard>
    <DCArtboard id="pg-6-bot" label="6 players · scrolled to the end" width={W} height={H}><Screen mode="X01 · 501" players={X01_6} scroll="bottom"/></DCArtboard>
    <DCArtboard id="pg-long" label="Long names (24 chars)" width={W} height={H}><Screen mode="X01 · 501" players={LONG}/></DCArtboard>
    <DCArtboard id="pg-tie" label="Tie · shared 2nd place" width={W} height={H}><Screen mode="X01 · 501" players={TIE}/></DCArtboard>
    <DCArtboard id="pg-degraded" label="Roster changed · degraded" width={W} height={H}><Screen mode="X01 · 501" players={X01} notice noChart noDetails degraded summary={SUMMARY_DEGRADED}/></DCArtboard>
    <DCArtboard id="pg-wild" label="Wildcard · no Elo for anyone" width={W} height={H}><Screen mode="WILDCARD" players={WILD}/></DCArtboard>
  </DCSection>
</>);
