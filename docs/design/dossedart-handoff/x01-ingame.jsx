// DOSSEDART — X01 in-game (Cockpit locked + sidescroll carousel)
// Layout: TopBar · player carousel (horizontal scroll, active in
// center w/ remaining + last + checkout tip) · big dartboard ·
// action bar (UNDO · MISS · MENU). The carousel is the entire
// scoreboard — prev/next peek so you can sidescroll between
// players. Auto-snaps to the active player.

const G_W = 820, G_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const PURPLE  = '#7B3FFF';
const RED     = '#FF3050';
const GREEN   = '#3DFF8E';
const BG      = '#0a0014';
const SURFACE = '#1a0030';

const PLAYERS = [
  { handle:'JON', name:'Jonas',   color:CYAN,    remaining:241, lastDarts:['T19','S5','S20'],   lastLabel:'S20 (20)',  state:'idle' },
  { handle:'AND', name:'Andreas', color:YELLOW,  remaining:170, lastDarts:['T20','T20','—'],    lastLabel:'T20 (60)',  dartIdx:2, state:'active', tip:['T20','T20','D-Bull'] },
  { handle:'MIA', name:'Mia',     color:MAGENTA, remaining:32,  lastDarts:['T20','S16','D8'],   lastLabel:'D8 (16)',   state:'checkout' },
];
const ACTIVE_IDX = 1;

const Frame = ({ children }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:G_W, height:G_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
      {children}
    </div>
  );
};

const TopBar = () => (
  <div style={{padding:'10px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>X01 · 501 · DOUBLE OUT</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>LEG 1/3 · RND 7</div>
  </div>
);

const DartDots = ({ idx=2, color=YELLOW, size=14 }) => (
  <div style={{display:'flex', gap:6}}>
    {[0,1,2].map(i => (
      <div key={i} style={{
        width:size, height:size, borderRadius:'50%',
        background: i < idx ? color : 'transparent',
        border: `2px solid ${color}`,
        boxShadow: i < idx ? `0 0 8px ${color}aa` : 'none',
      }}></div>
    ))}
  </div>
);

// ─── Player card (active vs peek) ───────────────────────────────
const ActiveCard = ({ p }) => (
  <div style={{flex:'0 0 86%', padding:'14px 18px', background:`linear-gradient(180deg, ${p.color}18 0%, transparent 100%)`, border:`3px solid ${p.color}`, boxShadow:`0 0 18px ${p.color}55, inset 0 0 18px ${p.color}22`, display:'flex', flexDirection:'column', position:'relative'}}>
    <div style={{position:'absolute', top:-9, left:18, padding:'3px 9px', background:p.color, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:10, letterSpacing:1.5, boxShadow:`0 0 8px ${p.color}aa`}}>▶ NOW THROWING</div>
    <div style={{display:'flex', alignItems:'flex-start', gap:14}}>
      <div style={{width:60, height:60, background:BG, border:`3px solid ${p.color}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:16, color:p.color, textShadow:`0 0 8px ${p.color}aa`, flexShrink:0, boxShadow:`0 0 14px ${p.color}55`}}>{p.handle}</div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:'#fff', letterSpacing:1, lineHeight:1, marginTop:4}}>{p.name.toUpperCase()}</div>
        <div style={{display:'flex', alignItems:'center', gap:10, marginTop:8}}>
          <DartDots idx={p.dartIdx} color={p.color} size={14}/>
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>DART {p.dartIdx + 1} / 3</div>
        </div>
      </div>
      <div style={{textAlign:'right'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>REMAINING</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:56, color:p.color, lineHeight:1, textShadow:`0 0 18px ${p.color}aa`, letterSpacing:-2, marginTop:2}}>{p.remaining}</div>
      </div>
    </div>
    <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginTop:10, padding:'8px 10px', background:BG, border:`1px solid ${p.color}66`}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>LAST</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:p.color, textShadow:`0 0 6px ${p.color}aa`}}>{p.lastLabel}</div>
    </div>
    {p.tip && (
      <div style={{marginTop:8, padding:'8px 10px', background:`${GREEN}15`, border:`1px dashed ${GREEN}aa`, display:'flex', alignItems:'center', gap:10}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:GREEN, letterSpacing:1.5, textShadow:`0 0 6px ${GREEN}aa`}}>✓ OUT</div>
        <div style={{flex:1, fontFamily:'"VT323", monospace', fontSize:18, color:'#fff', letterSpacing:3, textAlign:'center'}}>
          {p.tip.map((t, i) => (
            <span key={i}>
              <span style={{color:GREEN, fontFamily:'"Press Start 2P", monospace', fontSize:11}}>{t}</span>
              {i < p.tip.length - 1 && <span style={{color:'rgba(255,255,255,0.3)'}}> › </span>}
            </span>
          ))}
        </div>
      </div>
    )}
  </div>
);

const PeekCard = ({ p, side='left' }) => (
  <div style={{flex:'0 0 7%', padding:'12px 6px', background:SURFACE, border:`2px solid ${p.color}`, opacity:0.45, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:6, position:'relative'}}>
    {p.state === 'checkout' && <div style={{position:'absolute', top:-7, right:-4, padding:'2px 5px', background:GREEN, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:7, letterSpacing:1, boxShadow:`0 0 6px ${GREEN}aa`}}>OUT</div>}
    <div style={{width:28, height:28, background:BG, border:`2px solid ${p.color}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:9, color:p.color, textShadow:`0 0 6px ${p.color}aa`}}>{p.handle}</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:'#fff', letterSpacing:-.5}}>{p.remaining}</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:11, color:'rgba(255,255,255,0.5)', letterSpacing:1, writingMode: side==='left' ? 'vertical-rl' : 'vertical-lr', transform: side==='left' ? 'rotate(180deg)' : 'none'}}>{side === 'left' ? '◀ PREV' : 'NEXT ▶'}</div>
  </div>
);

// ─── Carousel ───────────────────────────────────────────────────
const Carousel = () => {
  const prev = PLAYERS[ACTIVE_IDX - 1];
  const next = PLAYERS[ACTIVE_IDX + 1];
  const active = PLAYERS[ACTIVE_IDX];
  return (
    <div style={{padding:'16px 0 14px', borderBottom:`1px dashed ${MAGENTA}66`}}>
      <div style={{padding:'0 22px 8px', display:'flex', alignItems:'center', justifyContent:'space-between'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:CYAN, letterSpacing:1.5}}>► PLAYERS · SWIPE TO BROWSE</div>
        <div style={{display:'flex', gap:5}}>
          {PLAYERS.map((p, i) => (
            <div key={p.handle} style={{width:i===ACTIVE_IDX?22:10, height:5, background:i===ACTIVE_IDX?p.color:'rgba(255,255,255,0.2)', boxShadow:i===ACTIVE_IDX?`0 0 6px ${p.color}aa`:'none'}}></div>
          ))}
        </div>
      </div>
      <div style={{display:'flex', alignItems:'stretch', gap:6, padding:'0 8px', overflow:'hidden'}}>
        {prev && <PeekCard p={prev} side="left"/>}
        <ActiveCard p={active}/>
        {next && <PeekCard p={next} side="right"/>}
      </div>
    </div>
  );
};

// ─── Dartboard (placeholder visual, big) ────────────────────────
const Dartboard = ({ size=620 }) => {
  const cx = size/2, cy = size/2;
  const rings = [
    { r: size*0.49, fill: BG,           stroke: MAGENTA, sw: 2 },
    { r: size*0.46, fill: MAGENTA+'22', stroke: 'transparent' },
    { r: size*0.42, fill: BG,           stroke: 'rgba(255,255,255,0.1)' },
    { r: size*0.30, fill: MAGENTA+'18', stroke: 'transparent' },
    { r: size*0.26, fill: BG,           stroke: 'rgba(255,255,255,0.1)' },
    { r: size*0.10, fill: GREEN+'33',   stroke: GREEN, sw: 1.5 },
    { r: size*0.04, fill: RED,          stroke: YELLOW, sw: 1.5 },
  ];
  const spokes = Array.from({length:20}, (_,i) => {
    const a = (i / 20) * Math.PI * 2 - Math.PI / 2;
    const r1 = size * 0.10, r2 = size * 0.46;
    return [cx + Math.cos(a)*r1, cy + Math.sin(a)*r1, cx + Math.cos(a)*r2, cy + Math.sin(a)*r2];
  });
  const hits = [
    { x: cx + 0.30*size*Math.cos(-Math.PI/2 - 0.04), y: cy + 0.30*size*Math.sin(-Math.PI/2 - 0.04), c: YELLOW },
    { x: cx + 0.32*size*Math.cos(-Math.PI/2 + 0.06), y: cy + 0.32*size*Math.sin(-Math.PI/2 + 0.06), c: YELLOW },
  ];
  const nums = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5];
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{display:'block'}}>
      <defs>
        <radialGradient id="bg2" cx="50%" cy="50%">
          <stop offset="0%" stopColor="#1a0030"/>
          <stop offset="100%" stopColor={BG}/>
        </radialGradient>
      </defs>
      <circle cx={cx} cy={cy} r={size*0.49} fill="url(#bg2)"/>
      {rings.map((r, i) => (
        <circle key={i} cx={cx} cy={cy} r={r.r} fill={r.fill} stroke={r.stroke} strokeWidth={r.sw||1}/>
      ))}
      {spokes.map((s, i) => (
        <line key={i} x1={s[0]} y1={s[1]} x2={s[2]} y2={s[3]} stroke="rgba(255,0,170,0.3)" strokeWidth="1"/>
      ))}
      {Array.from({length:20}, (_,i)=>{
        const a = (i / 20) * Math.PI * 2 - Math.PI / 2 - (Math.PI / 20);
        const r = size * 0.485;
        const x = cx + Math.cos(a) * r;
        const y = cy + Math.sin(a) * r;
        return (
          <text key={i} x={x} y={y+4} fontFamily="Press Start 2P" fontSize="11" fill="rgba(255,255,255,0.55)" textAnchor="middle">{nums[i]}</text>
        );
      })}
      {hits.map((h,i)=>(
        <g key={i}>
          <circle cx={h.x} cy={h.y} r="5" fill={h.c} stroke="#fff" strokeWidth="1"/>
          <circle cx={h.x} cy={h.y} r="11" fill="none" stroke={h.c} strokeWidth="1" opacity="0.5"/>
        </g>
      ))}
    </svg>
  );
};

const ActionBar = () => (
  <div style={{padding:'12px 22px 18px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:8, position:'relative', zIndex:6}}>
    <div style={{padding:'14px', background:SURFACE, border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:12, color:'#fff', letterSpacing:1.5, flex:1, textAlign:'center'}}>↶ UNDO</div>
    <div style={{padding:'14px', background:'#FF7A00', border:`2px solid #FFA500`, fontFamily:'"Press Start 2P", monospace', fontSize:14, color:BG, letterSpacing:2, flex:2, textAlign:'center', boxShadow:`0 0 14px #FF7A0088`}}>✗ MISS</div>
    <div style={{padding:'14px', background:SURFACE, border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:12, color:'#fff', letterSpacing:1.5, flex:1, textAlign:'center'}}>⋯ MENU</div>
  </div>
);

const Cockpit = () => (
  <Frame>
    <TopBar/>
    <Carousel/>
    <div style={{flex:1, display:'flex', alignItems:'center', justifyContent:'center', position:'relative', padding:'8px 0'}}>
      <Dartboard size={640}/>
      <div style={{position:'absolute', top:14, left:22, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:CYAN, letterSpacing:1.5}}>► TAP TO SCORE</div>
    </div>
    <ActionBar/>
  </Frame>
);

// ─── STATE: BUST ────────────────────────────────────────────────
// Triggered when score goes <0, ends on 1, or non-double finish.
// Big red takeover. Score reverts. Turn ends after CONTINUE.
const BustState = () => (
  <Frame>
    <TopBar/>
    <Carousel/>
    <div style={{flex:1, display:'flex', alignItems:'center', justifyContent:'center', position:'relative', padding:'8px 0'}}>
      <Dartboard size={640}/>
    </div>
    <ActionBar/>
    <div style={{position:'absolute', inset:0, background:`${RED}1f`, zIndex:7, display:'flex', alignItems:'center', justifyContent:'center', backdropFilter:'blur(2px)'}}>
      <div style={{position:'absolute', inset:0, border:`6px solid ${RED}`, boxShadow:`inset 0 0 80px ${RED}aa, 0 0 40px ${RED}aa`, animation:'none'}}></div>
      <div style={{textAlign:'center', padding:'30px 50px', background:BG, border:`4px solid ${RED}`, boxShadow:`0 0 40px ${RED}, inset 0 0 30px ${RED}55`}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:YELLOW, letterSpacing:2, marginBottom:18}}>► ANDREAS</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:96, color:RED, letterSpacing:6, textShadow:`0 0 24px ${RED}, 0 0 8px ${RED}`, lineHeight:1}}>BUST</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:22, color:'rgba(255,255,255,0.8)', letterSpacing:3, marginTop:18}}>WENT BELOW 2 · SCORE REVERTS</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginTop:10}}>170 → 170</div>
        <div style={{marginTop:24, padding:'14px 28px', background:RED, color:'#fff', fontFamily:'"Press Start 2P", monospace', fontSize:13, letterSpacing:2, display:'inline-block', boxShadow:`0 0 14px ${RED}aa`}}>CONTINUE ▶</div>
      </div>
    </div>
  </Frame>
);

// ─── STATE: SUDDEN DEATH ────────────────────────────────────────
// First to hit a double wins the leg. Banner pinned under TopBar.
const SuddenDeathState = () => (
  <Frame>
    <TopBar/>
    <div style={{padding:'10px 22px', background:`linear-gradient(90deg, ${RED} 0%, #FF7A00 100%)`, color:'#fff', fontFamily:'"Press Start 2P", monospace', fontSize:12, letterSpacing:3, textAlign:'center', boxShadow:`0 0 16px ${RED}88`, borderBottom:`2px solid #fff`, position:'relative', zIndex:6}}>
      ⚡ SUDDEN DEATH · FIRST DOUBLE WINS ⚡
    </div>
    <Carousel/>
    <div style={{flex:1, display:'flex', alignItems:'center', justifyContent:'center', position:'relative', padding:'8px 0'}}>
      <Dartboard size={620}/>
      <div style={{position:'absolute', top:14, left:22, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:RED, letterSpacing:1.5, textShadow:`0 0 6px ${RED}aa`}}>► HIT ANY DOUBLE</div>
    </div>
    <ActionBar/>
  </Frame>
);

// ─── STATE: WINNER (leg) ────────────────────────────────────────
const WinnerState = () => (
  <Frame>
    <TopBar/>
    <div style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', padding:'40px 30px', position:'relative', gap:24}}>
      <div style={{position:'absolute', inset:0, background:`radial-gradient(ellipse at center, ${MAGENTA}33 0%, transparent 60%)`, pointerEvents:'none'}}></div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:28, color:YELLOW, letterSpacing:6, textShadow:`0 0 12px ${YELLOW}aa`, position:'relative'}}>★ ★ ★ ★ ★</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:18, color:'rgba(255,255,255,0.6)', letterSpacing:3, position:'relative'}}>LEG 1 WINNER</div>
      <div style={{width:200, height:200, background:BG, border:`5px solid ${MAGENTA}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:48, color:MAGENTA, textShadow:`0 0 18px ${MAGENTA}`, boxShadow:`0 0 40px ${MAGENTA}aa, inset 0 0 30px ${MAGENTA}33`, position:'relative'}}>MIA</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:48, color:'#fff', letterSpacing:3, textShadow:`0 0 14px ${MAGENTA}aa`, position:'relative', textAlign:'center'}}>MIA</div>
      <div style={{display:'flex', gap:20, fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.7)', letterSpacing:2, position:'relative'}}>
        <div>16 DARTS</div>
        <div style={{color:MAGENTA}}>·</div>
        <div>AVG 31.3</div>
        <div style={{color:MAGENTA}}>·</div>
        <div>HIGH 121</div>
      </div>
      <div style={{padding:'14px 24px', background:`${MAGENTA}22`, border:`2px dashed ${MAGENTA}`, fontFamily:'"VT323", monospace', fontSize:18, color:'#fff', letterSpacing:3, position:'relative', marginTop:8}}>
        CHECKOUT · <span style={{color:GREEN, fontFamily:'"Press Start 2P", monospace', fontSize:11}}>T20 › S16 › D8</span>
      </div>
      <div style={{display:'flex', gap:8, fontFamily:'"Press Start 2P", monospace', fontSize:11, letterSpacing:2, marginTop:8, position:'relative'}}>
        <div style={{padding:'6px 12px', background:`${CYAN}33`, border:`1px solid ${CYAN}`, color:CYAN}}>JON · 241</div>
        <div style={{padding:'6px 12px', background:`${YELLOW}33`, border:`1px solid ${YELLOW}`, color:YELLOW}}>AND · 170</div>
      </div>
    </div>
    <div style={{padding:'16px 22px 22px', background:'#000', borderTop:`2px solid ${MAGENTA}`, display:'flex', gap:10, position:'relative', zIndex:6}}>
      <div style={{padding:'16px', background:SURFACE, border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, flex:1, textAlign:'center'}}>END MATCH</div>
      <div style={{padding:'16px', background:MAGENTA, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:13, color:BG, letterSpacing:2, flex:2, textAlign:'center', boxShadow:`0 0 14px ${MAGENTA}aa`}}>NEXT LEG ▶</div>
    </div>
  </Frame>
);

// ─── STATE: PLAYER REMOVED MID-GAME ────────────────────────────
const RemovedState = () => {
  const removed = { handle:'AND', name:'Andreas', color:YELLOW };
  return (
    <Frame>
      <TopBar/>
      <Carousel/>
      <div style={{flex:1, display:'flex', alignItems:'center', justifyContent:'center', position:'relative', padding:'8px 0'}}>
        <Dartboard size={620}/>
        <div style={{position:'absolute', top:'50%', left:'50%', transform:'translate(-50%, -50%)', padding:'24px 36px', background:BG, border:`3px solid ${RED}`, boxShadow:`0 0 24px ${RED}aa`, textAlign:'center', maxWidth:480}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:RED, letterSpacing:2, marginBottom:14}}>⚠ PLAYER REMOVED</div>
          <div style={{display:'flex', alignItems:'center', justifyContent:'center', gap:14, marginBottom:14}}>
            <div style={{width:48, height:48, background:BG, border:`3px solid ${removed.color}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:14, color:removed.color, opacity:0.5}}>{removed.handle}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:18, color:'#fff', letterSpacing:2, textDecoration:'line-through', textDecorationColor:RED, textDecorationThickness:3}}>{removed.name.toUpperCase()}</div>
          </div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.7)', letterSpacing:2, marginBottom:16}}>STATS DROPPED · TURN ORDER RESHUFFLED</div>
          <div style={{display:'flex', gap:10, justifyContent:'center'}}>
            <div style={{padding:'10px 18px', background:SURFACE, border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'#fff', letterSpacing:1.5}}>↶ UNDO</div>
            <div style={{padding:'10px 18px', background:RED, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'#fff', letterSpacing:1.5, boxShadow:`0 0 10px ${RED}aa`}}>CONFIRM ▶</div>
          </div>
        </div>
      </div>
      <ActionBar/>
    </Frame>
  );
};

// ─── STATE: TURN END (transition) ──────────────────────────────
// 3rd dart thrown, score posted, "next up" banner before swipe.
const TurnEndState = () => (
  <Frame>
    <TopBar/>
    <Carousel/>
    <div style={{flex:1, display:'flex', alignItems:'center', justifyContent:'center', position:'relative', padding:'8px 0'}}>
      <Dartboard size={620}/>
      <div style={{position:'absolute', inset:0, background:'rgba(10,0,20,0.55)', display:'flex', alignItems:'center', justifyContent:'center', flexDirection:'column', gap:18}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.55)', letterSpacing:3}}>TURN COMPLETE · 100 SCORED</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:32, color:'#fff', letterSpacing:3, textShadow:`0 0 12px ${MAGENTA}aa`}}>NEXT UP</div>
        <div style={{display:'flex', alignItems:'center', gap:14, padding:'12px 22px', background:BG, border:`3px solid ${MAGENTA}`, boxShadow:`0 0 18px ${MAGENTA}aa`}}>
          <div style={{width:44, height:44, background:BG, border:`3px solid ${MAGENTA}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:MAGENTA, textShadow:`0 0 8px ${MAGENTA}aa`}}>MIA</div>
          <div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:'#fff', letterSpacing:2}}>MIA</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:MAGENTA, letterSpacing:2}}>32 REMAINING · CHECKOUT</div>
          </div>
        </div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.45)', letterSpacing:2, marginTop:6}}>SWIPE LEFT OR TAP ▶</div>
      </div>
    </div>
    <ActionBar/>
  </Frame>
);

// ─── STATE: MATCH WON (best of) ────────────────────────────────
const MatchWonState = () => (
  <Frame>
    <TopBar/>
    <div style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', padding:'30px 30px', position:'relative', gap:18}}>
      <div style={{position:'absolute', inset:0, background:`radial-gradient(ellipse at center, ${YELLOW}22 0%, transparent 60%)`, pointerEvents:'none'}}></div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:YELLOW, letterSpacing:4, textShadow:`0 0 10px ${YELLOW}aa`, position:'relative'}}>★ MATCH WON ★</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.55)', letterSpacing:3, position:'relative', marginTop:-6}}>BEST OF 3 · 2–1</div>
      <div style={{width:220, height:220, background:BG, border:`6px solid ${MAGENTA}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:54, color:MAGENTA, textShadow:`0 0 22px ${MAGENTA}`, boxShadow:`0 0 50px ${MAGENTA}aa, inset 0 0 35px ${MAGENTA}33`, position:'relative'}}>MIA</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:54, color:'#fff', letterSpacing:4, textShadow:`0 0 18px ${MAGENTA}aa`, position:'relative'}}>MIA</div>
      <div style={{display:'flex', gap:10, position:'relative', marginTop:6}}>
        {[{l:'L1',w:'MIA',c:MAGENTA},{l:'L2',w:'JON',c:CYAN},{l:'L3',w:'MIA',c:MAGENTA}].map((leg,i)=>(
          <div key={i} style={{padding:'10px 16px', background:SURFACE, border:`2px solid ${leg.c}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:leg.c, letterSpacing:1.5, textAlign:'center'}}>
            <div style={{fontSize:9, color:'rgba(255,255,255,0.5)', marginBottom:4}}>{leg.l}</div>
            {leg.w}
          </div>
        ))}
      </div>
      <div style={{display:'flex', gap:18, fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.7)', letterSpacing:2, position:'relative', marginTop:6}}>
        <div>52 DARTS</div>
        <div style={{color:MAGENTA}}>·</div>
        <div>AVG 33.7</div>
        <div style={{color:MAGENTA}}>·</div>
        <div>HIGH 140</div>
      </div>
    </div>
    <div style={{padding:'16px 22px 22px', background:'#000', borderTop:`2px solid ${MAGENTA}`, display:'flex', gap:10, position:'relative', zIndex:6}}>
      <div style={{padding:'16px', background:SURFACE, border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, flex:1, textAlign:'center'}}>RECAP</div>
      <div style={{padding:'16px', background:SURFACE, border:`2px solid ${YELLOW}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, flex:1, textAlign:'center'}}>REMATCH</div>
      <div style={{padding:'16px', background:MAGENTA, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:13, color:BG, letterSpacing:2, flex:2, textAlign:'center', boxShadow:`0 0 14px ${MAGENTA}aa`}}>HOME ▶</div>
    </div>
  </Frame>
);

// ─── STATE: MENU / PAUSE ───────────────────────────────────────
const MenuState = () => (
  <Frame>
    <TopBar/>
    <Carousel/>
    <div style={{flex:1, display:'flex', alignItems:'center', justifyContent:'center', position:'relative', padding:'8px 0'}}>
      <Dartboard size={620}/>
    </div>
    <ActionBar/>
    <div style={{position:'absolute', inset:0, background:'rgba(10,0,20,0.78)', backdropFilter:'blur(3px)', zIndex:7, display:'flex', alignItems:'center', justifyContent:'center'}}>
      <div style={{width:520, background:BG, border:`3px solid ${CYAN}`, boxShadow:`0 0 28px ${CYAN}aa`, padding:'4px'}}>
        <div style={{padding:'12px 18px', borderBottom:`2px dashed ${CYAN}55`, display:'flex', alignItems:'center', justifyContent:'space-between'}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:2}}>⋯ MATCH MENU</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>✕ CLOSE</div>
        </div>
        {[
          {l:'RESUME',          k:'TAP TO CONTINUE',        c:GREEN, primary:true},
          {l:'EDIT LAST THROW', k:'CHANGE PREVIOUS DART',   c:YELLOW},
          {l:'REMOVE PLAYER',   k:'DROP SOMEONE MID-MATCH', c:'#FF7A00'},
          {l:'RESTART LEG',     k:'CLEAR SCORES, KEEP ORDER', c:CYAN},
          {l:'ABANDON MATCH',   k:'NO STATS SAVED',         c:RED},
        ].map((row, i) => (
          <div key={i} style={{padding:'14px 18px', display:'flex', alignItems:'center', justifyContent:'space-between', borderBottom: i<4 ? `1px dashed ${CYAN}22` : 'none', background: row.primary ? `${row.c}15` : 'transparent'}}>
            <div>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color: row.primary ? row.c : '#fff', letterSpacing:1.5, textShadow: row.primary ? `0 0 6px ${row.c}aa` : 'none'}}>{row.l}</div>
              <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginTop:4}}>{row.k}</div>
            </div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color: row.c}}>▶</div>
          </div>
        ))}
      </div>
    </div>
  </Frame>
);

const X01Ingame = () => (
  <>
    <DCSection
      id="x01-ingame"
      title="X01 — In game (cockpit · sidescroll)"
      subtitle="Cockpit locked. Player carousel up top — active card center, prev/next peek so you can sidescroll between players. Active card carries: name, dart-counter, big remaining, last-throw label, checkout tip when finishable. Dartboard ~640px. UNDO · MISS · MENU dock at the bottom.">
      <DCArtboard id="x01-cockpit" label="Cockpit · default · sidescroll players" width={G_W} height={G_H}><Cockpit/></DCArtboard>
    </DCSection>
    <DCSection
      id="x01-states"
      title="X01 — States"
      subtitle="Overlay states triggered by game events. BUST locks the screen until CONTINUE. SUDDEN DEATH pins a banner under the topbar. TURN END is the brief transition before the carousel auto-snaps. PLAYER REMOVED is a confirm modal. MENU is the pause / edit-last / abandon sheet. WINNER takes the screen between legs; MATCH WON is the bigger end-of-match takeover with leg breakdown.">
      <DCArtboard id="x01-bust" label="BUST · turn ends, score reverts" width={G_W} height={G_H}><BustState/></DCArtboard>
      <DCArtboard id="x01-sudden-death" label="SUDDEN DEATH · first double wins" width={G_W} height={G_H}><SuddenDeathState/></DCArtboard>
      <DCArtboard id="x01-turn-end" label="TURN END · next-up transition" width={G_W} height={G_H}><TurnEndState/></DCArtboard>
      <DCArtboard id="x01-menu" label="MENU · pause / edit / abandon sheet" width={G_W} height={G_H}><MenuState/></DCArtboard>
      <DCArtboard id="x01-removed" label="PLAYER REMOVED · mid-match confirm" width={G_W} height={G_H}><RemovedState/></DCArtboard>
      <DCArtboard id="x01-winner" label="LEG WON · between-leg takeover" width={G_W} height={G_H}><WinnerState/></DCArtboard>
      <DCArtboard id="x01-match-won" label="MATCH WON · end of best-of" width={G_W} height={G_H}><MatchWonState/></DCArtboard>
    </DCSection>
  </>
);

window.X01Ingame = X01Ingame;
