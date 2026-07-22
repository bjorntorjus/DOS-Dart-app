// DOSSEDART — Around the Clock cockpit (3 progress-metaphor directions)
// Next gamemode after X01 (dartboard) + Cricket (matrix-tap). ATC's mechanic
// is genuinely different: each player chases their OWN single moving target up
// a 1→20 ladder (hit to advance; D/T = ×N advances multiple steps). The open
// design question is purely "how does progress around the clock READ?".
//
// Three full cockpits, same locked chrome + tokens as X01/Cricket:
//   A · CLOCK RING   — literal around-the-clock; the iconic hero  ← RECOMMENDED
//   B · RACE LANES   — 1→20 tracks per player; the "who's ahead" race
//   C · TARGET HERO  — huge current-target number + slim standings (X01-consistent)
//
// Locked from the cricket round: single highlight (active = cyan, opponents =
// phosphor — no per-player rainbow), no throw suggestions, S/D/T tap cells feed
// engine.applyHit(segment, multiplier). No new game logic.

const A_W = 820, A_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#1a0030';
const PHOSPHOR= '#D9D2C2';

const ACTIVE_C = CYAN;
const TOTAL = 20; // 1→20, no bull (setup default)

// ── Game scenario (3 players · 1→20 · D/T = ×N · round 7) ───────
// done = target - 1 (you've completed every number below your current target).
const PLAYERS = [
  { handle:'AND', name:'Andreas', target:14, last:'14',  active:false },
  { handle:'JON', name:'Jonas',   target:11, last:'T9',  active:true, dartIdx:2 },
  { handle:'MIA', name:'Mia',     target:6,  last:'MISS', active:false },
];
const doneOf = (p) => p.target - 1;
const ACTIVE = PLAYERS.find(p => p.active);
const OPPS   = PLAYERS.filter(p => !p.active);

// One-time keyframes (subtle live-canvas pulse; static in screenshots/print).
if (typeof document !== 'undefined' && !document.getElementById('atc-kf')) {
  const s = document.createElement('style');
  s.id = 'atc-kf';
  s.textContent = `
    @keyframes atcPulse { 0%,100%{opacity:1} 50%{opacity:.45} }
    @keyframes atcGlow { 0%,100%{box-shadow:0 0 14px ${CYAN}66,0 0 0 ${CYAN}00}
                          50%{box-shadow:0 0 26px ${CYAN}aa,0 0 6px ${CYAN}55} }
    @media (prefers-reduced-motion: reduce){
      .atc-pulse,.atc-glow{animation:none!important}
    }`;
  document.head.appendChild(s);
}

// ── Shared chrome ───────────────────────────────────────────────
const Frame = ({ children }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:A_W, height:A_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
      {children}
    </div>
  );
};

const TopBar = ({ dir }) => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>AROUND THE CLOCK · 1→20</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>RND 7</div>
  </div>
);

const DartDots = ({ idx=2, color=CYAN, size=11 }) => (
  <div style={{display:'flex', gap:6}}>
    {[0,1,2].map(i => (
      <div key={i} style={{width:size, height:size, borderRadius:'50%', background:i<idx?color:'transparent', border:`2px solid ${color}`, boxShadow:i<idx?`0 0 8px ${color}aa`:'none'}}></div>
    ))}
  </div>
);

const ActionBar = () => (
  <div style={{padding:'12px 16px 16px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:10, position:'relative', zIndex:6}}>
    <div style={{flex:1, padding:'14px', border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:2, padding:'14px', background:ORANGE, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:BG, letterSpacing:2, textAlign:'center', boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:1, padding:'14px', border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5, textAlign:'center'}}>⋯ MENU</div>
  </div>
);

// Active strip — identity + dart progress; right side shows the CURRENT TARGET
// (ATC's headline number, the equivalent of X01's REMAINING / cricket's POINTS).
const ActiveStrip = ({ showTarget=true }) => {
  const p = ACTIVE, c = ACTIVE_C;
  return (
    <div style={{padding:'13px 22px', display:'flex', alignItems:'center', gap:14, background:`linear-gradient(90deg, ${c}1f 0%, transparent 100%)`, borderBottom:`3px solid ${c}`, boxShadow:`0 0 18px ${c}44`, position:'relative', zIndex:6}}>
      <div style={{width:50, height:50, background:BG, border:`3px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:c, textShadow:`0 0 8px ${c}aa`, flexShrink:0, boxShadow:`0 0 14px ${c}55`}}>{p.handle}</div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:10}}>
          <span style={{color:c, fontFamily:'"Press Start 2P", monospace', fontSize:14, letterSpacing:1.5, textShadow:`0 0 6px ${c}aa`}}>▶ {p.name.toUpperCase()}</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>DART {p.dartIdx + 1} / 3</span>
        </div>
        <div style={{display:'flex', alignItems:'center', gap:10, marginTop:7}}>
          <DartDots idx={p.dartIdx} color={c}/>
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.7)', letterSpacing:2}}>LAST · <span style={{color:p.last==='MISS'?ORANGE:GREEN, fontFamily:'"Press Start 2P", monospace', fontSize:10}}>{p.last}</span></div>
        </div>
      </div>
      {showTarget && (
        <div style={{textAlign:'right'}}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>TARGET</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:38, color:c, lineHeight:1, textShadow:`0 0 16px ${c}aa`, marginTop:4}}>{p.target}</div>
        </div>
      )}
    </div>
  );
};

// S/D/T tap cells for the current target. D/T = ×N → show the step gain.
// (BULL would render BULL / D-BULL; here we are 1→20 so all numeric.)
const StepCells = ({ target, big=false }) => {
  const c = ACTIVE_C;
  const subs = [
    { label:`${target}`,  step:'+1' },
    { label:`D${target}`, step:'+2' },
    { label:`T${target}`, step:'+3' },
  ];
  return (
    <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:10}}>
      {subs.map(s => (
        <div key={s.label} style={{background:`${c}12`, border:`2px solid ${c}`, boxShadow:`0 0 12px ${c}33`, padding:big?'18px 0 12px':'13px 0 9px', display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:big?28:20, color:c, textShadow:`0 0 10px ${c}aa`, letterSpacing:.5}}>{s.label}</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:big?17:14, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>{s.step} STEP{s.step==='+1'?'':'S'}</div>
        </div>
      ))}
    </div>
  );
};

// Compact opponent readout — phosphor, glanceable. Shows current target + a
// 20-segment progress meter (done lit, current marked, rest dim).
const OppMeter = ({ p, segs=20 }) => {
  const done = doneOf(p);
  return (
    <div style={{flex:1, minWidth:0, padding:'11px 13px', border:`1px solid ${PHOSPHOR}33`, background:`${PHOSPHOR}08`, display:'flex', flexDirection:'column', gap:8}}>
      <div style={{display:'flex', alignItems:'baseline', justifyContent:'space-between'}}>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:PHOSPHOR, letterSpacing:1}}>{p.handle}</span>
        <span style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>ON <b style={{color:PHOSPHOR, fontFamily:'"Press Start 2P", monospace', fontSize:11}}>{p.target}</b></span>
      </div>
      <div style={{display:'flex', gap:2, height:9}}>
        {Array.from({length:segs}).map((_,i)=>{
          const n = i+1;
          const isDone = n <= done, isCur = n === p.target;
          return <div key={i} style={{flex:1, background:isCur?PHOSPHOR:isDone?`${GREEN}cc`:'rgba(255,255,255,0.1)', boxShadow:isCur?`0 0 6px ${PHOSPHOR}`:'none'}}></div>;
        })}
      </div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.4)', letterSpacing:2}}>{done} / {TOTAL} DONE</div>
    </div>
  );
};

// ════════════════════════════════════════════════════════════════
// A · CLOCK RING  (recommended)
// ════════════════════════════════════════════════════════════════
const ClockRing = ({ size=440, target }) => {
  const done = target - 1;
  const cx = size/2, cy = size/2;
  const rNum = size*0.42;          // number ring radius
  const rTrack = size*0.30;        // progress arc radius
  const stroke = 14;
  const circ = 2*Math.PI*rTrack;
  const frac = done / TOTAL;
  return (
    <div style={{position:'relative', width:size, height:size}}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{display:'block'}}>
        {/* progress arc */}
        <circle cx={cx} cy={cy} r={rTrack} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth={stroke}/>
        <circle cx={cx} cy={cy} r={rTrack} fill="none" stroke={GREEN} strokeWidth={stroke}
          strokeDasharray={`${circ*frac} ${circ}`} strokeLinecap="butt"
          transform={`rotate(-90 ${cx} ${cy})`} style={{filter:`drop-shadow(0 0 6px ${GREEN}aa)`}}/>
        {/* tick spokes between numbers */}
        {Array.from({length:TOTAL}).map((_,i)=>{
          const a = -Math.PI/2 + i*(2*Math.PI/TOTAL) + (Math.PI/TOTAL);
          const x1=cx+Math.cos(a)*(rNum-22), y1=cy+Math.sin(a)*(rNum-22);
          const x2=cx+Math.cos(a)*(rNum+18), y2=cy+Math.sin(a)*(rNum+18);
          return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke="rgba(255,0,170,0.18)" strokeWidth="1"/>;
        })}
      </svg>
      {/* numbers 1→20 */}
      {Array.from({length:TOTAL}).map((_,i)=>{
        const n = i+1;
        const a = -Math.PI/2 + i*(2*Math.PI/TOTAL);
        const x = cx+Math.cos(a)*rNum, y = cy+Math.sin(a)*rNum;
        const isDone = n < target, isCur = n === target;
        const col = isCur ? CYAN : isDone ? GREEN : 'rgba(217,210,194,0.32)';
        return (
          <div key={n} className={isCur?'atc-pulse':''} style={{position:'absolute', left:x, top:y, transform:'translate(-50%,-50%)',
            width:isCur?42:30, height:isCur?42:30, display:'flex', alignItems:'center', justifyContent:'center',
            border:isCur?`2px solid ${CYAN}`:'none', background:isCur?`${CYAN}1a`:'transparent', borderRadius:'50%',
            fontFamily:'"Press Start 2P", monospace', fontSize:isCur?15:12, color:col,
            textShadow:isCur?`0 0 10px ${CYAN}`:isDone?`0 0 6px ${GREEN}88`:'none',
            animation:isCur?'atcPulse 1.4s ease-in-out infinite':'none'}}>{n}</div>
        );
      })}
      {/* center readout */}
      <div style={{position:'absolute', inset:0, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:4}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.5)', letterSpacing:3}}>TARGET</div>
        <div className="atc-pulse" style={{fontFamily:'"Press Start 2P", monospace', fontSize:84, color:CYAN, lineHeight:1, textShadow:`0 0 24px ${CYAN}aa`, animation:'atcPulse 1.4s ease-in-out infinite'}}>{target}</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:GREEN, letterSpacing:1, marginTop:6, textShadow:`0 0 8px ${GREEN}88`}}>{done} <span style={{color:'rgba(255,255,255,0.4)'}}>OF</span> {TOTAL}</div>
      </div>
    </div>
  );
};

const CockpitA = () => (
  <Frame>
    <TopBar/>
    <ActiveStrip/>
    {/* opponents — compact phosphor meters */}
    <div style={{padding:'14px 16px 0', display:'flex', gap:12}}>
      {OPPS.map(p => <OppMeter key={p.handle} p={p}/>)}
    </div>
    {/* hero clock */}
    <div style={{flex:1, display:'flex', alignItems:'center', justifyContent:'center', minHeight:0, position:'relative'}}>
      <div style={{position:'absolute', width:470, height:470, borderRadius:'50%', boxShadow:`0 0 80px ${MAGENTA}33`, pointerEvents:'none'}}></div>
      <ClockRing target={ACTIVE.target}/>
    </div>
    {/* input */}
    <div style={{padding:'0 16px 14px'}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.45)', letterSpacing:2, marginBottom:9, textAlign:'center'}}>HIT TARGET <b style={{color:YELLOW, fontFamily:'"Press Start 2P", monospace', fontSize:11}}>{ACTIVE.target}</b> — DOUBLE/TRIPLE SKIPS AHEAD</div>
      <StepCells target={ACTIVE.target}/>
    </div>
    <ActionBar/>
  </Frame>
);

// ════════════════════════════════════════════════════════════════
// B · RACE LANES
// ════════════════════════════════════════════════════════════════
const Lane = ({ p, active }) => {
  const done = doneOf(p);
  const c = active ? CYAN : PHOSPHOR;
  return (
    <div style={{border:`2px solid ${active?c:`${PHOSPHOR}33`}`, background:active?`${c}10`:`${PHOSPHOR}06`, boxShadow:active?`0 0 18px ${c}33`:'none', padding:active?'13px 14px 14px':'11px 14px', display:'flex', flexDirection:'column', gap:active?11:8}}>
      <div style={{display:'flex', alignItems:'center', gap:10}}>
        <div style={{width:active?38:30, height:active?38:30, background:BG, border:`2px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:active?11:10, color:c, textShadow:`0 0 6px ${c}aa`, flexShrink:0}}>{p.handle}</div>
        <div style={{flex:1, fontFamily:'"Press Start 2P", monospace', fontSize:active?13:11, color:active?'#fff':PHOSPHOR, letterSpacing:1}}>{active && <span style={{color:c}}>▶ </span>}{p.name.toUpperCase()}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.45)', letterSpacing:1}}>ON</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:active?18:14, color:c, textShadow:`0 0 8px ${c}aa`, minWidth:active?40:30, textAlign:'right'}}>{p.target}</div>
      </div>
      {/* the 1→20 track */}
      <div style={{display:'flex', gap:active?3:2, alignItems:'flex-end'}}>
        {Array.from({length:TOTAL}).map((_,i)=>{
          const n=i+1, isDone=n<=done, isCur=n===p.target;
          return (
            <div key={n} style={{flex:1, position:'relative'}}>
              {isCur && active && <div style={{position:'absolute', bottom:'100%', left:'50%', transform:'translateX(-50%)', marginBottom:4, fontFamily:'"Press Start 2P", monospace', fontSize:8, color:CYAN, whiteSpace:'nowrap', textShadow:`0 0 6px ${CYAN}`}}>▼{n}</div>}
              <div className={isCur&&active?'atc-glow':''} style={{height:active?(isCur?26:18):(isCur?16:12), background:isCur?c:isDone?`${GREEN}d0`:'rgba(255,255,255,0.08)',
                boxShadow:isCur?`0 0 8px ${c}`:isDone&&active?`0 0 4px ${GREEN}66`:'none',
                animation:isCur&&active?'atcGlow 1.4s ease-in-out infinite':'none'}}></div>
            </div>
          );
        })}
      </div>
      {active
        ? (<div style={{marginTop:3}}><StepCells target={p.target}/></div>)
        : (<div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.4)', letterSpacing:2}}>{done} / {TOTAL} DONE · LAST {p.last}</div>)
      }
    </div>
  );
};

const CockpitB = () => {
  // order lanes by progress (leader on top) — reads like standings
  const ordered = [...PLAYERS].sort((a,b)=>doneOf(b)-doneOf(a));
  return (
    <Frame>
      <TopBar/>
      <ActiveStrip showTarget={false}/>
      <div style={{flex:1, padding:'16px', display:'flex', flexDirection:'column', gap:12, minHeight:0}}>
        {ordered.map(p => <Lane key={p.handle} p={p} active={p.active}/>)}
      </div>
      <ActionBar/>
    </Frame>
  );
};

// ════════════════════════════════════════════════════════════════
// C · TARGET HERO + standings (X01-consistent)
// ════════════════════════════════════════════════════════════════
const StandingRow = ({ p, rank, active }) => {
  const done = doneOf(p);
  const c = active ? CYAN : PHOSPHOR;
  return (
    <div style={{display:'grid', gridTemplateColumns:'30px 64px 1fr 64px', alignItems:'center', gap:12, padding:'10px 12px', background:active?`${c}12`:'transparent', borderBottom:`1px solid ${MAGENTA}22`}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:rank===1?YELLOW:'rgba(255,255,255,0.4)', textShadow:rank===1?`0 0 6px ${YELLOW}88`:'none'}}>{rank}</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:c, letterSpacing:1, textShadow:`0 0 6px ${c}88`}}>{active&&'▶'}{p.handle}</div>
      <div style={{display:'flex', gap:2, height:11}}>
        {Array.from({length:TOTAL}).map((_,i)=>{
          const n=i+1, isDone=n<=done, isCur=n===p.target;
          return <div key={i} style={{flex:1, background:isCur?c:isDone?`${GREEN}cc`:'rgba(255,255,255,0.1)', boxShadow:isCur?`0 0 6px ${c}`:'none'}}></div>;
        })}
      </div>
      <div style={{textAlign:'right', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, textShadow:`0 0 6px ${c}88`}}>{done}<span style={{color:'rgba(255,255,255,0.35)', fontSize:10}}>/{TOTAL}</span></div>
    </div>
  );
};

const CockpitC = () => {
  const ordered = [...PLAYERS].sort((a,b)=>doneOf(b)-doneOf(a));
  return (
    <Frame>
      <TopBar/>
      <ActiveStrip showTarget={false}/>
      {/* HERO — the active player's current target, X01-style focal number */}
      <div style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', minHeight:0, padding:'10px 16px', position:'relative'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:'rgba(255,255,255,0.5)', letterSpacing:5}}>NEXT TARGET</div>
        <div className="atc-pulse" style={{fontFamily:'"Press Start 2P", monospace', fontSize:200, color:CYAN, lineHeight:1, textShadow:`0 0 50px ${CYAN}aa`, margin:'4px 0', animation:'atcPulse 1.4s ease-in-out infinite'}}>{ACTIVE.target}</div>
        <div style={{display:'flex', alignItems:'center', gap:10}}>
          <div style={{height:10, width:240, background:'rgba(255,255,255,0.1)', position:'relative'}}>
            <div style={{position:'absolute', inset:0, width:`${doneOf(ACTIVE)/TOTAL*100}%`, background:GREEN, boxShadow:`0 0 8px ${GREEN}aa`}}></div>
          </div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:GREEN, textShadow:`0 0 8px ${GREEN}88`}}>{doneOf(ACTIVE)} OF {TOTAL}</div>
        </div>
        <div style={{width:'100%', maxWidth:560, marginTop:26}}><StepCells target={ACTIVE.target} big/></div>
      </div>
      {/* standings */}
      <div style={{margin:'0 16px 14px', border:`2px solid ${MAGENTA}55`}}>
        <div style={{padding:'8px 12px', background:`${MAGENTA}15`, borderBottom:`2px solid ${MAGENTA}55`, fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.6)', letterSpacing:2}}>STANDINGS · WHO'S FURTHEST AROUND</div>
        {ordered.map((p,i) => <StandingRow key={p.handle} p={p} rank={i+1} active={p.active}/>)}
      </div>
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
  <div style={{boxSizing:'border-box', width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:15, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · anbefalt retning A</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Around the Clock · klokke-ring</div>
    </div>

    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Hvorfor A</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Klokke-ringen <b style={{color:'#2a251f'}}>er</b> spillet — du ser hele reisen 1→20, hvor du er, og hvor langt igjen, i ett blikk. Den eier en egen visuell identitet (X01 = brett, Cricket = matrise, ATC = ring) uten å gjenbruke et mønster. B (race-baner) er sterkest for ren standings-spenning; C (mål-helt) er mest lik X01. Alle tre bruker samme chrome + input.</div>
    </div>

    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Farger (per rolle)</div>
      <SpecRow zone="Aktiv spiller · ring-mål + strip" val="#00E5FF" hex={CYAN}/>
      <SpecRow zone="Fullført segment (done)" val="#3DFF8E" hex={GREEN}/>
      <SpecRow zone="Motstandere · meter + glyphs" val="phosphor" hex={PHOSPHOR}/>
      <SpecRow zone="Mål-label / leder-rank" val="#FFD200" hex={YELLOW}/>
      <SpecRow zone="Ramme + spokes + standings" val="#FF00AA" hex={MAGENTA}/>
      <SpecRow zone="MISS / chrome-accent" val="#FF7A00" hex={ORANGE}/>
      <SpecRow zone="BG + frame" val="#0A0014" hex={BG}/>
    </div>

    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Input + steg-logikk</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Tre celler = nåværende mål som <b style={{color:'#2a251f'}}>S / D / T</b> → <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>engine.applyHit(segment, multiplier)</code>. Med <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>countMultiples</code> hopper D = +2 og T = +3 segmenter (cellene viser «+N STEPS»). Treff feil tall = bom (samme som MISS, ingen framgang). 3 dart per tur; egen <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>currentTarget</code> per spiller.</div>
    </div>

    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Arcade-cockpit','Erstatt classic AppBar + «NEXT TARGET / n OF 20» + outline-knapper med DOSSEDART-chrome: ArcadeFrame (CRT), topbar, active-strip, klokke-ring, action-bar. Samme byggeklosser som X01 + Cricket.'],
        ['2','Ringen = framgang','20 tall i sirkel (start kl.12 = 1, med klokka). n < target = grønn (done), n == target = cyan puls + ring, n > target = dim phosphor. Senter: stort mål-tall + arc (done/20). Med BULL → 21. punkt = «25» øverst.'],
        ['3','Én farge-logikk','Aktiv = cyan, motstandere = phosphor, done = grønn. Ingen per-spiller-farger. Følger Cricket/home-mønsteret.'],
        ['4','Motstandere glanceable','To kompakte phosphor-metere (mål + 20-segment progress). Ingen forslag/coaching — bare hvor de er.'],
        ['5','Config-aware','Topbar viser retning (1→20 / 20→1) + «+BULL». Reverse → ringen teller ned (target synker). Random order endrer kun spiller-rekkefølge, ikke layout.'],
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
        <b>Konsistens:</b> samme chrome (topbar / active-strip / action-bar) og farge-prinsipp som X01 + Cricket — chrome magenta, aktiv = cyan, gul = label, grønn = success/done, oransje = MISS. Ulik kropp (ring vs brett vs matrise) er bevisst per spillmodus.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const AtcCockpit = () => (
  <>
    <DCSection
      id="atc-directions"
      title="Around the Clock — cockpit (3 framgangs-retninger)"
      subtitle="ATC-mekanikken er ny: hver spiller jager sitt EGET vandrende mål opp en 1→20-stige (treff for å avansere; D/T = ×N hopper flere steg). Det åpne spørsmålet er kun «hvordan leses framgang rundt klokka?». Tre fulle cockpiter med samme låste chrome + tokens som X01/Cricket. Anbefalt: A · klokke-ring — mest tematisk og egen identitet.">
      <DCArtboard id="atc-a" label="A · Klokke-ring  ← anbefalt" width={A_W} height={A_H}><CockpitA/></DCArtboard>
      <DCArtboard id="atc-b" label="B · Race-baner (standings)" width={A_W} height={A_H}><CockpitB/></DCArtboard>
      <DCArtboard id="atc-c" label="C · Mål-helt + standings (X01-lik)" width={A_W} height={A_H}><CockpitC/></DCArtboard>
      <DCArtboard id="atc-spec" label="Implementasjon · spec + tokens (retning A)" width={680} height={1180}><SpecCard/></DCArtboard>
    </DCSection>
  </>
);

window.AtcCockpit = AtcCockpit;

// ── Locked final — direction A (clock ring) + spec ──────────────
const AtcCockpitFinal = () => (
  <DCSection
    id="atc-final"
    title="Around the Clock cockpit — final (klokke-ring)"
    subtitle="Valgt retning A. Klokke-ringen er spillet: 20 tall i sirkel, fullførte segment grønne, nåværende mål (cyan, pulser) i senter med stort tall + framgangs-arc. Motstandere = kompakte phosphor-metere. Input = S/D/T-celler for nåværende mål (D/T = ×N hopper flere steg). Samme chrome + farge-logikk som X01 + Cricket.">
    <DCArtboard id="atcf-cockpit" label="Cockpit · Around the Clock · klokke-ring" width={A_W} height={A_H}><CockpitA/></DCArtboard>
    <DCArtboard id="atcf-spec" label="Implementasjon · spec + tokens" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.AtcCockpitFinal = AtcCockpitFinal;
