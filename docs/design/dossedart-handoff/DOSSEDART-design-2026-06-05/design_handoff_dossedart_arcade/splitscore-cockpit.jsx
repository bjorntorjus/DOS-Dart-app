// DOSSEDART — Splitscore (Halve It) cockpit (3 directions)
// Next gamemode after Killer. Rules: everyone starts at 40. A sequence of
// rounds, each with a TARGET (a number 1-20, ANY double, ANY triple, or bull).
// You throw 3 darts at the target; points = sum of hits (segment×mult). Score
// ZERO in a round → your TOTAL IS HALVED (the round cell shows the amount lost,
// red ✗). Highest total after all rounds wins. Standard order:
//   15 · 16 · DOUBLE · 17 · 18 · TRIPLE · 19 · 20 · BULL  (9 rounds)
//
// Input is the full board (number/any-double/any-triple/bull all need it), but
// the SOUL is the round scorecard + the live "hit-or-halve" jeopardy. Open axis:
// how prominent is the scorecard vs the board, and how is the halve-risk shown?
//   A · SCORECARD     — the darts scorecard is the hero; board = compact input  ← REC
//   B · TARGET+BOARD  — big target + large board (live zone glows); mini standings
//   C · ROUND TRACK   — round stepper + big jeopardy panel; board compact
//
// Locked: active = cyan, others = phosphor (no rainbow). Full names, not 3-letter
// handles (collisions). Taps feed engine.applyHit(segment, multiplier).

const S_W = 820, S_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#1a0030';
const PHOSPHOR= '#D9D2C2';

// Standard sequence; current round = TRIPLE (index 5, round 6 of 9).
const ROUNDS = [
  { label:'15',   type:'number', n:15 },
  { label:'16',   type:'number', n:16 },
  { label:'DBL',  type:'double',  full:'DOUBLE' },
  { label:'17',   type:'number', n:17 },
  { label:'18',   type:'number', n:18 },
  { label:'TRP',  type:'triple',  full:'TRIPLE' },
  { label:'19',   type:'number', n:19 },
  { label:'20',   type:'number', n:20 },
  { label:'BULL', type:'bull',    full:'BULL' },
];
const CUR = 5;
const isSpecial = (r) => r.type !== 'number';

// Round cells: number = points, negative = HALVED (lost that much), null = unplayed,
// string = live this turn. Totals are committed (pre-current-turn).
const PLAYERS = [
  { name:'Jonas',   handle:'JON', active:true, dartIdx:1, turnPts:0, hit:false,
    cells:[45,48,36,-85,54,'LIVE',null,null,null], total:138 },
  { name:'Andreas', handle:'AND',
    cells:[30,-35,40,51,36,null,null,null,null], total:162 },
  { name:'Mia',     handle:'MIA',
    cells:[45,32,-59,17,-38,null,null,null,null], total:37 },
];
const ACTIVE = PLAYERS.find(p => p.active);
const LEADER = PLAYERS.reduce((a,b)=>b.total>a.total?b:a);
const halvedTo = (t) => Math.floor(t/2);

// keyframes
if (typeof document !== 'undefined' && !document.getElementById('spl-kf')) {
  const s = document.createElement('style');
  s.id = 'spl-kf';
  s.textContent = `
    @keyframes splPulse { 0%,100%{opacity:1} 50%{opacity:.4} }
    @keyframes splRisk { 0%,100%{box-shadow:0 0 10px ${RED}55; border-color:${RED}} 50%{box-shadow:0 0 22px ${RED}cc; border-color:#ff7088} }
    @keyframes splGlow { 0%,100%{opacity:.85} 50%{opacity:.35} }
    @media (prefers-reduced-motion: reduce){ .spl-pulse,.spl-risk,.spl-glow{animation:none!important} }`;
  document.head.appendChild(s);
}

// ── Shared chrome ───────────────────────────────────────────────
const Frame = ({ children }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:S_W, height:S_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
      {children}
    </div>
  );
};
const TopBar = () => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>SPLITSCORE · STANDARD</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>RND 6/9</div>
  </div>
);
const DartDots = ({ idx=1, color=CYAN, size=11 }) => (
  <div style={{display:'flex', gap:6}}>
    {[0,1,2].map(i => <div key={i} style={{width:size, height:size, borderRadius:'50%', background:i<idx?color:'transparent', border:`2px solid ${color}`, boxShadow:i<idx?`0 0 8px ${color}aa`:'none'}}></div>)}
  </div>
);
const ActionBar = () => (
  <div style={{padding:'12px 16px 16px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:10, position:'relative', zIndex:6}}>
    <div style={{flex:1, padding:'14px', border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:2, padding:'14px', background:ORANGE, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:BG, letterSpacing:2, textAlign:'center', boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:1, padding:'14px', border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5, textAlign:'center'}}>⋯ MENU</div>
  </div>
);

// Active strip — identity + dart dots + TOTAL (your headline number)
const ActiveStrip = ({ target } = {}) => {
  const p = ACTIVE, c = CYAN, r = target || ROUNDS[CUR];
  return (
    <div style={{padding:'12px 22px', display:'flex', alignItems:'center', gap:14, background:`linear-gradient(90deg, ${c}1f 0%, transparent 100%)`, borderBottom:`3px solid ${c}`, boxShadow:`0 0 18px ${c}44`, position:'relative', zIndex:6}}>
      <div style={{width:50, height:50, background:BG, border:`3px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:c, textShadow:`0 0 8px ${c}aa`, flexShrink:0, boxShadow:`0 0 14px ${c}55`}}>{p.handle}</div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:10}}>
          <span style={{color:c, fontFamily:'"Press Start 2P", monospace', fontSize:14, letterSpacing:1.5, textShadow:`0 0 6px ${c}aa`}}>▶ {p.name.toUpperCase()}</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>DART {p.dartIdx + 1} / 3</span>
        </div>
        <div style={{display:'flex', alignItems:'center', gap:10, marginTop:7}}>
          <DartDots idx={p.dartIdx} color={c}/>
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.65)', letterSpacing:2}}>MÅL · <span style={{color:YELLOW, fontFamily:'"Press Start 2P", monospace', fontSize:10}}>{r.full || r.label}</span></div>
        </div>
      </div>
      <div style={{textAlign:'right'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>TOTAL</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:36, color:c, lineHeight:1, textShadow:`0 0 16px ${c}aa`, marginTop:4}}>{p.total}</div>
      </div>
    </div>
  );
};

// Jeopardy bar — the emotional core. Not hit yet → red risk; hit → green safe.
const JeopardyBar = ({ target } = {}) => {
  const p = ACTIVE, r = target || ROUNDS[CUR];
  if (p.hit) {
    return (
      <div style={{margin:'12px 16px 0', padding:'11px 16px', border:`2px solid ${GREEN}`, background:`${GREEN}12`, boxShadow:`0 0 14px ${GREEN}33`, display:'flex', alignItems:'center', gap:12}}>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:GREEN, letterSpacing:1, textShadow:`0 0 6px ${GREEN}aa`}}>✓ SIKRET</span>
        <span style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.75)', letterSpacing:1}}>+{p.turnPts} denne runden · ingen halvering</span>
      </div>
    );
  }
  return (
    <div className="spl-risk" style={{margin:'12px 16px 0', padding:'11px 16px', border:`2px solid ${RED}`, background:`${RED}14`, display:'flex', alignItems:'center', gap:12, animation:'splRisk 0.9s ease-in-out infinite'}}>
      <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:RED, letterSpacing:1, textShadow:`0 0 6px ${RED}aa`}}>⚠ INGEN TREFF</span>
      <span style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.8)', letterSpacing:1, flex:1}}>Treff <b style={{color:YELLOW}}>{r.full || r.label}</b> eller total halveres</span>
      <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1}}>{p.total} <span style={{color:RED}}>→ {halvedTo(p.total)}</span></span>
    </div>
  );
};

// ── Scorecard (rounds × players) ────────────────────────────────
const Cell = ({ v, active, live }) => {
  if (live) return <div className="spl-pulse" style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:ACTIVE.hit?GREEN:RED, textShadow:`0 0 8px ${ACTIVE.hit?GREEN:RED}aa`, animation:'splPulse 0.9s ease-in-out infinite'}}>{ACTIVE.hit?`+${ACTIVE.turnPts}`:'⚠'}</div>;
  if (v === null || v === undefined) return <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.2)'}}>·</div>;
  if (v < 0) return <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:RED, textShadow:`0 0 6px ${RED}88`}}>{Math.abs(v)}<span style={{fontSize:10}}> ✗</span></div>;
  return <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:active?'#fff':'rgba(255,255,255,0.82)'}}>{v}</div>;
};
const Scorecard = ({ compact }) => {
  const colT = `64px repeat(${PLAYERS.length}, 1fr)`;
  return (
    <div style={{display:'flex', flexDirection:'column', border:`2px solid ${MAGENTA}55`, minHeight:0, flex:1}}>
      {/* header */}
      <div style={{display:'grid', gridTemplateColumns:colT, background:`${MAGENTA}15`, borderBottom:`2px solid ${MAGENTA}55`}}>
        <div style={{padding:'9px 0', textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.55)', letterSpacing:1, alignSelf:'center', borderRight:`1px solid ${MAGENTA}33`}}>RUNDE</div>
        {PLAYERS.map(p => (
          <div key={p.handle} style={{padding:'8px 4px', textAlign:'center', borderRight:`1px solid ${MAGENTA}22`, background:p.active?`${CYAN}1a`:'transparent'}}>
            <div style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:13, color:p.active?CYAN:PHOSPHOR, textShadow:p.active?`0 0 6px ${CYAN}aa`:'none', whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{p.active&&'▶ '}{p.name}</div>
          </div>
        ))}
      </div>
      {/* round rows */}
      {ROUNDS.map((r, ri) => {
        const cur = ri === CUR, done = ri < CUR;
        return (
          <div key={ri} style={{flex:1, display:'grid', gridTemplateColumns:colT, borderBottom: ri<ROUNDS.length-1?`1px solid ${MAGENTA}1c`:'none', background:cur?`${CYAN}10`:'transparent', minHeight:0, alignItems:'center', opacity:done?0.78:1}}>
            <div style={{borderRight:`1px solid ${MAGENTA}33`, display:'flex', alignItems:'center', justifyContent:'center', gap:5, height:'100%'}}>
              {cur && <span style={{color:CYAN, fontFamily:'"Press Start 2P", monospace', fontSize:9}}>▶</span>}
              <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:isSpecial(r)?9:12, color:cur?YELLOW:isSpecial(r)?'#ff7ad0':'rgba(255,210,0,0.7)', textShadow:cur?`0 0 6px ${YELLOW}88`:'none'}}>{r.label}</span>
            </div>
            {PLAYERS.map((p,pi) => (
              <div key={p.handle} style={{height:'100%', display:'flex', alignItems:'center', justifyContent:'center', borderRight: pi<PLAYERS.length-1?`1px solid ${MAGENTA}14`:'none', background:p.active&&cur?`${CYAN}14`:'transparent'}}>
                <Cell v={p.cells[ri]} active={p.active} live={p.cells[ri]==='LIVE'}/>
              </div>
            ))}
          </div>
        );
      })}
      {/* total row */}
      <div style={{display:'grid', gridTemplateColumns:colT, background:'#000', borderTop:`2px solid ${MAGENTA}55`}}>
        <div style={{padding:'10px 0', textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.7)', letterSpacing:1, borderRight:`1px solid ${MAGENTA}33`}}>SUM</div>
        {PLAYERS.map(p => {
          const lead = p === LEADER;
          const col = p.active?CYAN:lead?YELLOW:'#fff';
          return (
            <div key={p.handle} style={{padding:'9px 4px', textAlign:'center', borderRight:`1px solid ${MAGENTA}22`, background:p.active?`${CYAN}12`:'transparent'}}>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:17, color:col, textShadow:`0 0 8px ${col}aa`}}>{p.total}</div>
              {lead && <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:YELLOW, letterSpacing:1, marginTop:2}}>LEDER</div>}
            </div>
          );
        })}
      </div>
    </div>
  );
};

// Compact standings (for B) — totals only, leader gold, active cyan
const Standings = () => {
  const ordered = [...PLAYERS].sort((a,b)=>b.total-a.total);
  return (
    <div style={{display:'flex', gap:10}}>
      {ordered.map((p,i) => {
        const lead = p===LEADER, col = p.active?CYAN:lead?YELLOW:PHOSPHOR;
        return (
          <div key={p.handle} style={{flex:1, padding:'9px 12px', border:`2px solid ${p.active?CYAN:`${col}44`}`, background:p.active?`${CYAN}10`:'transparent', display:'flex', alignItems:'center', justifyContent:'space-between', gap:8}}>
            <div style={{minWidth:0}}>
              <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.45)', letterSpacing:1}}>{i+1}{lead?' · LEDER':''}</div>
              <div style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:14, color:p.active?'#fff':PHOSPHOR, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{p.name}</div>
            </div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:20, color:col, textShadow:`0 0 8px ${col}aa`}}>{p.total}</div>
          </div>
        );
      })}
    </div>
  );
};

// ── Dartboard (TWILIGHT) with the round's LIVE TARGET ZONE glowing ──
const TWI = { singles:['#1e0c40','#321760'], ring:['#1fb0c9','#c72e94'] };
const R_BULL=0.12, R_TRI_I=0.47, R_TRI_O=0.58, R_DBL_I=0.82, R_DBL_O=0.95, R_RIM=1.00, R_NUM=0.975, R_DBULL=0.05;
const SEGMENTS = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5];
const wedge = (cx,cy,rIn,rOut,a1,a2) => {
  const px=(r,a)=>cx+r*Math.cos(a), py=(r,a)=>cy+r*Math.sin(a);
  const large=(a2-a1)>Math.PI?1:0;
  return [`M ${px(rIn,a1)} ${py(rIn,a1)}`,`L ${px(rOut,a1)} ${py(rOut,a1)}`,`A ${rOut} ${rOut} 0 ${large} 1 ${px(rOut,a2)} ${py(rOut,a2)}`,`L ${px(rIn,a2)} ${py(rIn,a2)}`,`A ${rIn} ${rIn} 0 ${large} 0 ${px(rIn,a1)} ${py(rIn,a1)}`,'Z'].join(' ');
};
const Dartboard = ({ size=600, target, dim }) => {
  const cx=size/2, cy=size/2, R=size*0.47, seg=(2*Math.PI)/20;
  const segAngles = SEGMENTS.map((_,i)=>{ const c=-Math.PI/2+i*seg; return [c-seg/2,c+seg/2]; });
  const numIdx = target && target.type==='number' ? SEGMENTS.indexOf(target.n) : -1;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{display:'block'}}>
      <circle cx={cx} cy={cy} r={R*R_RIM} fill="#000"/>
      {segAngles.map(([a1,a2],i)=><path key={`is${i}`} d={wedge(cx,cy,R_BULL*R,R_TRI_I*R,a1,a2)} fill={TWI.singles[i%2]}/>)}
      {segAngles.map(([a1,a2],i)=><path key={`t${i}`} d={wedge(cx,cy,R_TRI_I*R,R_TRI_O*R,a1,a2)} fill={TWI.ring[i%2]}/>)}
      {segAngles.map(([a1,a2],i)=><path key={`os${i}`} d={wedge(cx,cy,R_TRI_O*R,R_DBL_I*R,a1,a2)} fill={TWI.singles[i%2]}/>)}
      {segAngles.map(([a1,a2],i)=><path key={`d${i}`} d={wedge(cx,cy,R_DBL_I*R,R_DBL_O*R,a1,a2)} fill={TWI.ring[i%2]}/>)}
      {/* dim everything except the live target zone */}
      {dim && <circle cx={cx} cy={cy} r={R*R_RIM} fill="rgba(10,0,20,0.64)"/>}
      {/* LIVE TARGET ZONE — glows yellow */}
      {target && target.type==='triple' && segAngles.map(([a1,a2],i)=><path key={`gt${i}`} className="spl-glow" d={wedge(cx,cy,R_TRI_I*R,R_TRI_O*R,a1,a2)} fill={`${YELLOW}cc`} stroke={YELLOW} strokeWidth="1.5" style={{animation:'splGlow 1.3s ease-in-out infinite', filter:`drop-shadow(0 0 4px ${YELLOW})`}}/>)}
      {target && target.type==='double' && segAngles.map(([a1,a2],i)=><path key={`gd${i}`} className="spl-glow" d={wedge(cx,cy,R_DBL_I*R,R_DBL_O*R,a1,a2)} fill={`${YELLOW}cc`} stroke={YELLOW} strokeWidth="1.5" style={{animation:'splGlow 1.3s ease-in-out infinite', filter:`drop-shadow(0 0 4px ${YELLOW})`}}/>)}
      {numIdx>=0 && <path className="spl-glow" d={wedge(cx,cy,R_BULL*R,R_DBL_O*R,segAngles[numIdx][0],segAngles[numIdx][1])} fill={`${YELLOW}55`} stroke={YELLOW} strokeWidth="2.5" style={{animation:'splGlow 1.3s ease-in-out infinite', filter:`drop-shadow(0 0 8px ${YELLOW})`}}/>}
      {segAngles.map(([a1],i)=>{ const x1=cx+Math.cos(a1)*R_BULL*R, y1=cy+Math.sin(a1)*R_BULL*R, x2=cx+Math.cos(a1)*R_DBL_O*R, y2=cy+Math.sin(a1)*R_DBL_O*R; return <line key={`sp${i}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke="rgba(0,0,0,0.6)" strokeWidth="1"/>; })}
      <circle cx={cx} cy={cy} r={(R_DBL_O+(R_RIM-R_DBL_O)/2)*R} fill="none" stroke={BG} strokeWidth={(R_RIM-R_DBL_O)*R}/>
      <circle cx={cx} cy={cy} r={R_BULL*R} fill={target&&target.type==='bull'?YELLOW:'#1fb0c9'} stroke={target&&target.type==='bull'?'#fff':'#0a3a22'} strokeWidth="2" className={target&&target.type==='bull'?'spl-glow':''} style={target&&target.type==='bull'?{animation:'splGlow 1.3s ease-in-out infinite', filter:`drop-shadow(0 0 8px ${YELLOW})`}:{}}/>
      <circle cx={cx} cy={cy} r={R_DBULL*R} fill={RED} stroke={YELLOW} strokeWidth="1.5"/>
      {SEGMENTS.map((n,i)=>{ const c=-Math.PI/2+i*seg, x=cx+Math.cos(c)*R_NUM*R, y=cy+Math.sin(c)*R_NUM*R; const hot=numIdx===i; return <text key={`n${i}`} x={x} y={y+4} fontFamily="'Press Start 2P', monospace" fontSize="11" fill={hot?YELLOW:'#fff'} textAnchor="middle">{n}</text>; })}
    </svg>
  );
};

// Target banner — big round target
const TargetBanner = ({ big, target }) => {
  const r = target || ROUNDS[CUR];
  const desc = r.type==='triple' ? 'enhver trippel teller · ×3' : r.type==='double' ? 'enhver dobbel teller · ×2' : r.type==='bull' ? 'bull = 25 · d-bull = 50' : `treff ${r.label} · S/D/T scorer`;
  return (
    <div style={{display:'flex', alignItems:'center', gap:16, padding:big?'4px 0':'2px 0'}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:big?22:18, color:'rgba(255,255,255,0.5)', letterSpacing:3}}>MÅL</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:big?48:30, color:YELLOW, letterSpacing:1, textShadow:`0 0 18px ${YELLOW}aa`}}>{r.full || r.label}</div>
      <div style={{flex:1, fontFamily:'"VT323", monospace', fontSize:big?20:16, color:'rgba(255,255,255,0.6)', letterSpacing:1, textAlign:'right'}}>{desc}</div>
    </div>
  );
};

// ════════════════════════════════════════════════════════════════
// A · SCORECARD HERO  (recommended)
// ════════════════════════════════════════════════════════════════
const CockpitA = () => (
  <Frame>
    <TopBar/>
    <ActiveStrip/>
    <JeopardyBar/>
    <div style={{flex:1, padding:'12px 16px 0', display:'flex', flexDirection:'column', minHeight:0}}>
      <Scorecard/>
    </div>
    {/* compact board = input, with the live target zone glowing */}
    <div style={{padding:'12px 16px 6px', display:'flex', alignItems:'center', gap:16}}>
      <div style={{position:'relative', width:150, height:150, flexShrink:0}}><Dartboard size={150} target={ROUNDS[CUR]}/></div>
      <div style={{flex:1}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:YELLOW, letterSpacing:1, marginBottom:7}}>TAPP BRETTET FOR Å REGISTRERE</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.65)', lineHeight:1.4, letterSpacing:1}}>Det gule feltet er rundens mål (<b style={{color:YELLOW}}>{ROUNDS[CUR].full}</b>). Bom på alle tre = total halveres.</div>
      </div>
    </div>
    <ActionBar/>
  </Frame>
);

// ════════════════════════════════════════════════════════════════
// B · TARGET + BOARD  (board hero)
// ════════════════════════════════════════════════════════════════
const CockpitB = () => (
  <Frame>
    <TopBar/>
    <ActiveStrip/>
    <div style={{padding:'14px 18px 0'}}><TargetBanner big/></div>
    <div style={{flex:1, position:'relative', display:'flex', alignItems:'center', justifyContent:'center', minHeight:0}}>
      <div style={{position:'absolute', width:560, height:560, borderRadius:'50%', boxShadow:`0 0 70px ${YELLOW}22`, pointerEvents:'none'}}></div>
      <Dartboard size={600} target={ROUNDS[CUR]}/>
    </div>
    <div style={{padding:'0 16px 6px'}}><Standings/></div>
    <ActionBar/>
  </Frame>
);

// ════════════════════════════════════════════════════════════════
// C · ROUND TRACK + JEOPARDY  (progression + risk)
// ════════════════════════════════════════════════════════════════
const RoundTrack = () => (
  <div style={{display:'flex', gap:6, padding:'2px 0'}}>
    {ROUNDS.map((r,i)=>{
      const cur=i===CUR, done=i<CUR;
      const col = cur?CYAN:done?'rgba(255,255,255,0.5)':'rgba(255,255,255,0.28)';
      return (
        <div key={i} style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', gap:5}}>
          <div style={{width:'100%', height:5, background:cur?CYAN:done?GREEN:'rgba(255,255,255,0.12)', boxShadow:cur?`0 0 8px ${CYAN}`:'none'}}></div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:isSpecial(r)?7:9, color:cur?CYAN:isSpecial(r)?'#ff7ad0':col, textShadow:cur?`0 0 6px ${CYAN}`:'none'}}>{r.label}</div>
        </div>
      );
    })}
  </div>
);
const CockpitC = () => {
  const r = ROUNDS[CUR], p = ACTIVE;
  return (
    <Frame>
      <TopBar/>
      <ActiveStrip/>
      <div style={{padding:'14px 16px 0'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginBottom:8}}>RUNDE-LØP · 6 AV 9</div>
        <RoundTrack/>
      </div>
      {/* big jeopardy panel */}
      <div style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', minHeight:0, padding:'10px 16px'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:'rgba(255,255,255,0.5)', letterSpacing:4}}>RUNDENS MÅL</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:72, color:YELLOW, lineHeight:1.1, textShadow:`0 0 28px ${YELLOW}aa`, margin:'6px 0 4px'}}>{r.full || r.label}</div>
        <div className="spl-risk" style={{marginTop:18, padding:'16px 22px', border:`2px solid ${RED}`, background:`${RED}14`, display:'flex', flexDirection:'column', alignItems:'center', gap:8, animation:'splRisk 0.9s ease-in-out infinite'}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:RED, letterSpacing:1, textShadow:`0 0 8px ${RED}aa`}}>⚠ TREFF ELLER HALVÉR</div>
          <div style={{display:'flex', alignItems:'center', gap:14, fontFamily:'"Press Start 2P", monospace', fontSize:26, color:'#fff'}}>
            <span>{p.total}</span>
            <span style={{color:'rgba(255,255,255,0.4)', fontSize:18}}>→</span>
            <span style={{color:RED, textShadow:`0 0 10px ${RED}aa`}}>{halvedTo(p.total)}</span>
          </div>
        </div>
        <div style={{position:'relative', width:170, height:170, marginTop:18}}><Dartboard size={170} target={r}/></div>
      </div>
      <div style={{padding:'0 16px 6px'}}><Standings/></div>
      <ActionBar/>
    </Frame>
  );
};

// ── Implementation spec card (paper · recommended = A) ──────────
const SpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}></div>
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);
const SpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:14, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · anbefalt retning A</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Splitscore · scorecard</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Hvorfor A</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Splitscore handler om <b style={{color:'#2a251f'}}>scorecardet</b> over tid — runde for runde, hvem som ble halvert, hvem som leder. Det er modusens egen identitet (ingen annen modus har et runde×spiller-scorecard med halverings-merker). A gjør kortet til helten, med en rød <b style={{color:'#2a251f'}}>jeopardy-bar</b> som viser «treff eller halvér → N» live. B er brett-først (godt for sikting); C fremhever runde-løpet + risiko. Alle deler input + farge-logikk.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Farger (per rolle)</div>
      <SpecRow zone="Aktiv spiller · kolonne + total" val="#00E5FF" hex={CYAN}/>
      <SpecRow zone="Rundens mål · label + brett-zone" val="#FFD200" hex={YELLOW}/>
      <SpecRow zone="Halvert runde (0 treff) · ✗" val="#FF3050" hex={RED}/>
      <SpecRow zone="Leder-total" val="#FFD200" hex={YELLOW}/>
      <SpecRow zone="Motstandere · kolonner" val="phosphor" hex={PHOSPHOR}/>
      <SpecRow zone="Ramme + scorecard-linjer" val="#FF00AA" hex={MAGENTA}/>
      <SpecRow zone="MISS / chrome-accent" val="#FF7A00" hex={ORANGE}/>
      <SpecRow zone="BG + frame" val="#0A0014" hex={BG}/>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Input + halverings-logikk</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Start 40. Per runde 3 dart mot målet → <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>round.isHit/pointsFor(segment,mult)</code>. Minst ett treff → <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>total += turnPts</code>. Null treff → <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>total = total ~/ 2</code> (cellen lagrer <b>-tap</b>, vises rødt «N ✗»). Standard: 15·16·DBL·17·18·TRP·19·20·BULL.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Arcade-cockpit','Erstatt classic AppBar + Material DataTable med DOSSEDART-chrome: ArcadeFrame (CRT), topbar, active-strip, scorecard, action-bar. Samme byggeklosser som de andre modusene.'],
        ['2','Scorecard = helten','Grid runde×spiller. Nåværende runde lyser cyan, live-celle pulser (+N grønn / ⚠ rød), halvert celle = rød «tap ✗», SUM-rad nederst med leder gul. Fulle navn i kolonner (ikke forkortelser).'],
        ['3','Jeopardy-bar','Over kortet: rød pulsende bar når ingen treff ennå — «treff {mål} eller total halveres → {total~/2}». Blir grønn «✓ sikret +N» idet et dart treffer. Modusens emosjonelle kjerne.'],
        ['4','Brett m/ live-zone','Kompakt brett som input; rundens mål-zone lyser gult (number → segmentet, DOUBLE → ytre ring, TRIPLE → indre ring, BULL → bull). Samme TWILIGHT-geometri som X01.'],
        ['5','Én farge-logikk','Aktiv=cyan, mål=gul, halvert/fare=rød, leder=gul, motstandere=phosphor. Ingen per-spiller-farger. Følger de andre modusene.'],
      ].map(([n,t,b])=>(
        <div key={n} style={{display:'flex', gap:11, padding:'8px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{flexShrink:0, width:22, height:22, borderRadius:'50%', background:'#2a8a52', color:'#fff', display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"JetBrains Mono", monospace', fontSize:12, fontWeight:700}}>{n}</div>
          <div style={{flex:1}}>
            <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:700, color:'#2a251f', marginBottom:2}}>{t}</div>
            <div style={{fontFamily:'"Inter", sans-serif', fontSize:12, lineHeight:1.5, color:'#5a544a'}}>{b}</div>
          </div>
        </div>
      ))}
    </div>
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#2a4a36'}}>
        <b>Konsistens:</b> samme chrome + farge-prinsipp som X01/Cricket/ATC/Killer. Det nye for Splitscore: et ekte scorecard + halverings-jeopardy. Brettet (med gul live-zone) er input, ikke helten.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const SplitscoreCockpit = () => (
  <DCSection
    id="splitscore-directions"
    title="Splitscore — cockpit (3 retninger)"
    subtitle="Splitscore (Halve It): start på 40, en sekvens av runder med hvert sitt mål (tall / enhver dobbel / enhver trippel / bull). 3 dart per runde — null treff = total HALVERES. Input er hele brettet, men sjelen er runde-scorecardet + «treff eller halvér»-spenningen. Anbefalt: A · scorecard — kortet er helten med en rød jeopardy-bar.">
    <DCArtboard id="spl-a" label="A · Scorecard  ← anbefalt" width={S_W} height={S_H}><CockpitA/></DCArtboard>
    <DCArtboard id="spl-b" label="B · Mål + brett" width={S_W} height={S_H}><CockpitB/></DCArtboard>
    <DCArtboard id="spl-c" label="C · Runde-løp + jeopardy" width={S_W} height={S_H}><CockpitC/></DCArtboard>
    <DCArtboard id="spl-spec" label="Implementasjon · spec + tokens (retning A)" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.SplitscoreCockpit = SplitscoreCockpit;

// ════════════════════════════════════════════════════════════════
// INPUT-FOCUS ALTERNATIVES (per feedback: full board is overkill when the
// round just says "14" or "ALL DOUBLES"). Two options, each shown for a
// NUMBER round (14 → 14/D14/T14) and a DOUBLE round (any number ×2).
// ════════════════════════════════════════════════════════════════
const T14  = { type:'number', n:14, label:'14', full:'14' };
const TDBL = { type:'double', label:'DBL', full:'DOUBLE' };

// number round → just the three cells for that number
const StepCellsBig = ({ target }) => {
  const n = target.n;
  const labs = [`${n}`, `D${n}`, `T${n}`];
  return (
    <div style={{display:'flex', flexDirection:'column', alignItems:'center', gap:18, width:'100%'}}>
      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:14, width:'100%', maxWidth:640}}>
        {labs.map(l=>(
          <div key={l} style={{border:`2px solid ${CYAN}`, background:`${CYAN}12`, boxShadow:`0 0 16px ${CYAN}33`, padding:'42px 0', display:'flex', alignItems:'center', justifyContent:'center'}}>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:38, color:CYAN, textShadow:`0 0 12px ${CYAN}aa`}}>{l}</div>
          </div>
        ))}
      </div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>kun <b style={{color:YELLOW}}>{n}</b> teller — single, dobbel eller trippel</div>
    </div>
  );
};
// double/triple round → pick which number you hit, at the round's multiplier
const NumberKeypad = ({ mult, includeDBull }) => {
  const nums = Array.from({length:20}, (_,i)=>i+1);
  return (
    <div style={{width:'100%', maxWidth:740, display:'flex', flexDirection:'column', gap:9}}>
      <div style={{display:'grid', gridTemplateColumns:'repeat(5, 1fr)', gap:9}}>
        {nums.map(n=>(
          <div key={n} style={{border:`2px solid ${CYAN}66`, background:`${CYAN}0c`, padding:'13px 0 9px', display:'flex', flexDirection:'column', alignItems:'center', gap:3}}>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:19, color:'#fff', textShadow:`0 0 6px ${CYAN}66`}}>{n}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:CYAN, letterSpacing:1}}>={n*mult}</div>
          </div>
        ))}
      </div>
      {includeDBull && (
        <div style={{border:`2px solid ${CYAN}66`, background:`${CYAN}0c`, padding:'13px 0', display:'flex', alignItems:'center', justifyContent:'center', gap:12}}>
          <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:'#fff'}}>D-BULL</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:17, color:CYAN, letterSpacing:1}}>= 50</span>
        </div>
      )}
    </div>
  );
};
const BullCells = () => (
  <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:14, width:'100%', maxWidth:540}}>
    {['BULL','D-BULL'].map(l=>(
      <div key={l} style={{border:`2px solid ${CYAN}`, background:`${CYAN}12`, boxShadow:`0 0 16px ${CYAN}33`, padding:'42px 0', display:'flex', alignItems:'center', justifyContent:'center'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:30, color:CYAN, textShadow:`0 0 12px ${CYAN}aa`}}>{l}</div>
      </div>
    ))}
  </div>
);
// the adaptive input — switches on round type
const InputArea = ({ target }) => {
  if (target.type==='number') return <StepCellsBig target={target}/>;
  if (target.type==='bull')   return <BullCells/>;
  const mult = target.type==='double'?2:3;
  return (
    <div style={{width:'100%', display:'flex', flexDirection:'column', alignItems:'center'}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:1, marginBottom:14, textAlign:'center', textShadow:`0 0 6px ${YELLOW}66`}}>ENHVER {target.type==='double'?'DOBBEL · ×2':'TRIPPEL · ×3'} — VELG TALLET DU TRAFF</div>
      <NumberKeypad mult={mult} includeDBull={target.type==='double'}/>
    </div>
  );
};

// ── ALT 1 · BOARD (like B, dimmed except live zone) ─────────────
const CockpitBoard = ({ target }) => (
  <Frame>
    <TopBar/>
    <ActiveStrip target={target}/>
    <div style={{padding:'12px 16px 0'}}><Standings/></div>
    <JeopardyBar target={target}/>
    <div style={{padding:'12px 18px 0'}}><TargetBanner target={target}/></div>
    <div style={{flex:1, position:'relative', display:'flex', alignItems:'center', justifyContent:'center', minHeight:0}}>
      <div style={{position:'absolute', width:520, height:520, borderRadius:'50%', boxShadow:`0 0 70px ${YELLOW}22`, pointerEvents:'none'}}></div>
      <Dartboard size={540} target={target} dim/>
    </div>
    <ActionBar/>
  </Frame>
);

// ── ALT 2 · NUMBER ONLY (no board; adaptive cells/keypad) ───────
const CockpitNumber = ({ target }) => (
  <Frame>
    <TopBar/>
    <ActiveStrip target={target}/>
    <div style={{padding:'12px 16px 0'}}><Standings/></div>
    <JeopardyBar target={target}/>
    <div style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', minHeight:0, padding:'18px 16px 0'}}>
      <div style={{marginBottom:24, textAlign:'center'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.5)', letterSpacing:4}}>SKYT PÅ</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:54, color:YELLOW, lineHeight:1.1, textShadow:`0 0 22px ${YELLOW}aa`, marginTop:8}}>{target.full || target.label}</div>
      </div>
      <InputArea target={target}/>
    </div>
    <ActionBar/>
  </Frame>
);

// ── Spec card for the adaptive-input approach ───────────────────
const SpecCard2 = () => (
  <div style={{boxSizing:'border-box', width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:15, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · adaptiv input</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Splitscore · input følger mål-typen</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Kjernen</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Hele brettet er unødvendig når runden bare ber om «14» eller «alle dobler». Inputen <b style={{color:'#2a251f'}}>tilpasser seg mål-typen</b> — to presentasjoner: <b style={{color:'#2a251f'}}>Kun tall</b> (anbefalt — raskest, minst støy) og <b style={{color:'#2a251f'}}>Brett</b> (når du vil visualisere sonen romlig). Begge bruker samme <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>applyHit(segment, mult)</code>.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Input per mål-type</div>
      {[
        ['Tall (f.eks. 14)','Tre celler: 14 / D14 / T14 (= 14 / 28 / 42 p). Kun det tallet teller. Brett-variant: kun segment 14 lyser, resten dimmes.'],
        ['Enhver DOBBEL','Alle tall kan treffes ×2 → tastatur 1–20 (hver = tall×2) + D-BULL (50). Brett-variant: hele dobbel-ringen lyser.'],
        ['Enhver TRIPPEL','Tastatur 1–20 (hver = tall×3). Ingen trippel-bull. Brett-variant: hele trippel-ringen lyser.'],
        ['BULL','To celler: BULL (25) / D-BULL (50). Brett-variant: bull lyser.'],
      ].map(([t,b])=>(
        <div key={t} style={{display:'flex', gap:11, padding:'9px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{flexShrink:0, width:90, fontFamily:'"JetBrains Mono", monospace', fontSize:12, fontWeight:700, color:'#7a4a2a'}}>{t}</div>
          <div style={{flex:1, fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.5, color:'#5a544a'}}>{b}</div>
        </div>
      ))}
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Beholdt rundt inputen</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Active-strip (din total + mål), <b style={{color:'#2a251f'}}>jeopardy-bar</b> (rød «treff eller halvér → N», blir grønn ved treff), og en kompakt <b style={{color:'#2a251f'}}>standings</b> (3 totaler, leder gul). Det fulle scorecardet flyttes til en «historikk»-knapp i ⋯ MENU — ikke i veien for inputen.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Farger (per rolle)</div>
      <SpecRow zone="Input-celler / aktiv / total" val="#00E5FF" hex={CYAN}/>
      <SpecRow zone="Rundens mål · label + zone" val="#FFD200" hex={YELLOW}/>
      <SpecRow zone="Halvert / fare / jeopardy" val="#FF3050" hex={RED}/>
      <SpecRow zone="Motstandere · standings" val="phosphor" hex={PHOSPHOR}/>
      <SpecRow zone="Ramme + linjer" val="#FF00AA" hex={MAGENTA}/>
      <SpecRow zone="BG + frame" val="#0A0014" hex={BG}/>
    </div>
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#2a4a36'}}>
        <b>Anbefaling:</b> «Kun tall» som standard — null bortkastet brett, mål-typen styrer cellene. Tilby «Brett»-visning som et valg for den som vil sikte romlig (samme live-zone gløder gult).
      </div>
    </div>
  </div>
);

// ── Canvas (input-focus) ────────────────────────────────────────
const SplitscoreInputFocus = () => (
  <DCSection
    id="splitscore-input"
    title="Splitscore — input-fokus (2 alternativer × 2 runde-typer)"
    subtitle="Per tilbakemelding: hele brettet er unødvendig når runden bare ber om «14» eller «alle dobler». To alternativer, hver vist for en TALL-runde (14 → 14/D14/T14) og en DOBBEL-runde (alle tall ×2). Alt 1 = brett (som B, dimmet utenom live-sonen). Alt 2 = kun tall (adaptive celler/tastatur). Begge beholder jeopardy-bar + kompakt standings. Anbefalt: kun tall.">
    <DCArtboard id="spi-num-num" label="Kun tall · TALL-runde (14 / D14 / T14)  ← anbefalt" width={S_W} height={S_H}><CockpitNumber target={T14}/></DCArtboard>
    <DCArtboard id="spi-num-dbl" label="Kun tall · DOBBEL-runde (tastatur 1–20 ×2)" width={S_W} height={S_H}><CockpitNumber target={TDBL}/></DCArtboard>
    <DCArtboard id="spi-board-num" label="Brett · TALL-runde (kun 14 lyser)" width={S_W} height={S_H}><CockpitBoard target={T14}/></DCArtboard>
    <DCArtboard id="spi-board-dbl" label="Brett · DOBBEL-runde (dobbel-ring lyser)" width={S_W} height={S_H}><CockpitBoard target={TDBL}/></DCArtboard>
    <DCArtboard id="spi-spec" label="Implementasjon · adaptiv input + tokens" width={680} height={1180}><SpecCard2/></DCArtboard>
  </DCSection>
);
window.SplitscoreInputFocus = SplitscoreInputFocus;
