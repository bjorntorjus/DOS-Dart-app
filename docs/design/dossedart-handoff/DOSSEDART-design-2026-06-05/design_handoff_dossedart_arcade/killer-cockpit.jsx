// DOSSEDART — Killer cockpit (3 combat-state directions)
// Next gamemode after Around the Clock. Killer is PvP elimination:
//   • each player OWNS a number 1–20 (thrown-for or random)
//   • hit your OWN number → you become a KILLER (armed). No damage that dart.
//   • as a killer, hit an OPPONENT's number → drain a life (×N w/ multiplyHits)
//   • BULL → +1 shield (D-BULL +3); shields absorb incoming damage first
//   • armed + hit own number again → SELF-HIT, you lose a life
//   • last player alive wins.
//
// The input is unavoidably the FULL dartboard (any of 20 numbers + bull is
// meaningful) — same board as X01. So the open design axis is: how does the
// COMBAT ROSTER (owned number · lives · armed · shields) read, and how board-
// forward is the layout?
//   A · BATTLE BOARD — board is hero & input; state lives ON the rim   ← REC
//   B · KILL GRID    — combat cards are hero; board demoted to a strip
//   C · ARENA        — board up top + full-width healthbar roster below
//
// Locked from prior rounds: active = cyan, opponents = phosphor, no per-player
// rainbow. Board geometry/colors identical to X01 (TWILIGHT). Taps feed
// engine.applyHit(segment, multiplier). No new game logic.

const K_W = 820, K_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#1a0030';
const PHOSPHOR= '#D9D2C2';

// Role map (within the locked palette):
//   CYAN = you · PHOSPHOR = opponents · RED = lives/danger/eliminated
//   ORANGE = KILLER/armed · GREEN = shields · YELLOW = your-number label
//   MAGENTA = chrome/frame

// ── Scenario (3 players · 3 lives · throw-pick · shields on · round 5) ──
// Drama: you (Jonas) are armed with a shield; Mia is unarmed on her last life.
const PLAYERS = [
  { handle:'JON', name:'Jonas',   num:20, lives:3, max:3, killer:true,  shields:1, active:true, dartIdx:1, last:'20' },
  { handle:'AND', name:'Andreas', num:7,  lives:2, max:3, killer:true,  shields:0, last:'T7'  },
  { handle:'MIA', name:'Mia',     num:13, lives:1, max:3, killer:false, shields:0, last:'MISS' },
];
const ACTIVE = PLAYERS.find(p => p.active);
const OPPS   = PLAYERS.filter(p => !p.active);

const SEGMENTS = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5];
const angleForNum = (n) => -Math.PI/2 + SEGMENTS.indexOf(n)*(2*Math.PI/20);

// ── keyframes (subtle live pulse; static in print/reduced-motion) ──
if (typeof document !== 'undefined' && !document.getElementById('kil-kf')) {
  const s = document.createElement('style');
  s.id = 'kil-kf';
  s.textContent = `
    @keyframes kilPulse { 0%,100%{opacity:1} 50%{opacity:.4} }
    @keyframes kilDanger { 0%,100%{box-shadow:0 0 10px ${RED}55} 50%{box-shadow:0 0 22px ${RED}cc} }
    @keyframes kilYou { 0%,100%{filter:drop-shadow(0 0 6px ${CYAN}aa)} 50%{filter:drop-shadow(0 0 18px ${CYAN})} }
    @media (prefers-reduced-motion: reduce){ .kil-pulse,.kil-danger,.kil-you{animation:none!important} }`;
  document.head.appendChild(s);
}

// ── Glyph bits ──────────────────────────────────────────────────
const Heart = ({ filled, size=16, low }) => (
  <svg width={size} height={size} viewBox="0 0 24 22" className={low&&filled?'kil-pulse':''}
    style={{display:'block', filter:filled?`drop-shadow(0 0 3px ${RED}cc)`:'none', animation:low&&filled?'kilPulse 0.9s ease-in-out infinite':'none'}}>
    <path d="M12 21C5 16.5 2 12.5 2 8.2 2 5.3 4.2 3 7 3c2 0 3.2 1.1 5 3 1.8-1.9 3-3 5-3 2.8 0 5 2.3 5 5.2 0 4.3-3 8.3-10 12.8z"
      fill={filled?RED:'none'} stroke={RED} strokeWidth="2" opacity={filled?1:0.3}/>
  </svg>
);
const Hearts = ({ lives, max, size=16 }) => {
  const low = lives === 1;
  return <div style={{display:'flex', gap:4}}>{Array.from({length:max}).map((_,i)=><Heart key={i} filled={i<lives} size={size} low={low}/>)}</div>;
};
const Shield = ({ size=15 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{display:'block', filter:`drop-shadow(0 0 3px ${GREEN}aa)`}}>
    <path d="M12 2l8 3v6c0 5-3.4 8.7-8 11-4.6-2.3-8-6-8-11V5z" fill={`${GREEN}33`} stroke={GREEN} strokeWidth="2"/>
  </svg>
);
const ShieldTag = ({ n }) => n>0 ? (
  <div style={{display:'flex', alignItems:'center', gap:4}}>
    <Shield/>
    <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:GREEN, textShadow:`0 0 6px ${GREEN}88`}}>×{n}</span>
  </div>
) : null;
const ArmedTag = ({ killer, big }) => (
  <div style={{display:'inline-flex', alignItems:'center', gap:6, padding:big?'5px 10px':'3px 7px',
    border:`2px solid ${killer?ORANGE:'rgba(255,255,255,0.25)'}`, background:killer?`${ORANGE}1f`:'transparent',
    boxShadow:killer?`0 0 10px ${ORANGE}55`:'none'}}>
    <span style={{width:8, height:8, borderRadius:'50%', background:killer?ORANGE:'rgba(255,255,255,0.3)', boxShadow:killer?`0 0 6px ${ORANGE}`:'none'}}></span>
    <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:big?11:9, letterSpacing:1, color:killer?ORANGE:'rgba(255,255,255,0.4)', textShadow:killer?`0 0 6px ${ORANGE}88`:'none'}}>{killer?'KILLER':'ARMING'}</span>
  </div>
);

// ── Shared chrome ───────────────────────────────────────────────
const Frame = ({ children }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:K_W, height:K_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
      {children}
    </div>
  );
};
const TopBar = () => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>KILLER · 3 LIVES · SHIELDS</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>RND 5</div>
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

// Active strip — identity + your combat stat block on the right
const ActiveStrip = ({ compact }) => {
  const p = ACTIVE, c = CYAN;
  return (
    <div style={{padding:'12px 22px', display:'flex', alignItems:'center', gap:14, background:`linear-gradient(90deg, ${c}1f 0%, transparent 100%)`, borderBottom:`3px solid ${c}`, boxShadow:`0 0 18px ${c}44`, position:'relative', zIndex:6}}>
      <div style={{width:50, height:50, background:BG, border:`3px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:c, textShadow:`0 0 8px ${c}aa`, flexShrink:0, boxShadow:`0 0 14px ${c}55`}}>{p.handle}</div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:10}}>
          <span style={{color:c, fontFamily:'"Press Start 2P", monospace', fontSize:14, letterSpacing:1.5, textShadow:`0 0 6px ${c}aa`}}>▶ {p.name.toUpperCase()}</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>DART {p.dartIdx + 1} / 3</span>
        </div>
        <div style={{display:'flex', alignItems:'center', gap:12, marginTop:8}}>
          <DartDots idx={p.dartIdx} color={c}/>
          <Hearts lives={p.lives} max={p.max} size={15}/>
          <ShieldTag n={p.shields}/>
          <ArmedTag killer={p.killer}/>
        </div>
      </div>
      <div style={{textAlign:'right'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>YOUR Nº</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:34, color:c, lineHeight:1, textShadow:`0 0 16px ${c}aa`, marginTop:4}}>{p.num}</div>
      </div>
    </div>
  );
};

// ── Dartboard (TWILIGHT — identical geometry to X01) ────────────
const TWI = { singles:['#1e0c40','#321760'], ring:['#1fb0c9','#c72e94'] };
const R_BULL=0.12, R_TRI_I=0.47, R_TRI_O=0.58, R_DBL_I=0.82, R_DBL_O=0.95, R_RIM=1.00, R_NUM=0.975, R_DBULL=0.05;
const wedge = (cx,cy,rIn,rOut,a1,a2) => {
  const px=(r,a)=>cx+r*Math.cos(a), py=(r,a)=>cy+r*Math.sin(a);
  const large=(a2-a1)>Math.PI?1:0;
  return [`M ${px(rIn,a1)} ${py(rIn,a1)}`,`L ${px(rOut,a1)} ${py(rOut,a1)}`,`A ${rOut} ${rOut} 0 ${large} 1 ${px(rOut,a2)} ${py(rOut,a2)}`,`L ${px(rIn,a2)} ${py(rIn,a2)}`,`A ${rIn} ${rIn} 0 ${large} 0 ${px(rIn,a1)} ${py(rIn,a1)}`,'Z'].join(' ');
};
// owners: [{num,color,vulnerable,you}]
const Dartboard = ({ size=600, owners=[] }) => {
  const cx=size/2, cy=size/2, R=size*0.47, seg=(2*Math.PI)/20;
  const segAngles = SEGMENTS.map((_,i)=>{ const c=-Math.PI/2+i*seg; return [c-seg/2,c+seg/2]; });
  const ownerOf = (n)=>owners.find(o=>o.num===n);
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{display:'block'}}>
      <circle cx={cx} cy={cy} r={R*R_RIM} fill="#000"/>
      {segAngles.map(([a1,a2],i)=><path key={`is${i}`} d={wedge(cx,cy,R_BULL*R,R_TRI_I*R,a1,a2)} fill={TWI.singles[i%2]}/>)}
      {segAngles.map(([a1,a2],i)=><path key={`t${i}`} d={wedge(cx,cy,R_TRI_I*R,R_TRI_O*R,a1,a2)} fill={TWI.ring[i%2]}/>)}
      {segAngles.map(([a1,a2],i)=><path key={`os${i}`} d={wedge(cx,cy,R_TRI_O*R,R_DBL_I*R,a1,a2)} fill={TWI.singles[i%2]}/>)}
      {segAngles.map(([a1,a2],i)=><path key={`d${i}`} d={wedge(cx,cy,R_DBL_I*R,R_DBL_O*R,a1,a2)} fill={TWI.ring[i%2]}/>)}
      {/* owned-segment highlight wedges — YOUR field is brightest/thickest */}
      {SEGMENTS.map((n,i)=>{
        const o=ownerOf(n); if(!o) return null;
        const [a1,a2]=segAngles[i]; const col=o.you?CYAN:RED; // you=cyan · all enemies=red
        const w = o.you?5:o.vulnerable?4:2.5;
        const fill = o.you?`${CYAN}42`:o.vulnerable?`${RED}3a`:`${RED}1e`;
        const cls = o.you?'kil-you':o.vulnerable?'kil-pulse':'';
        const anim = o.you?'kilYou 1.3s ease-in-out infinite':o.vulnerable?'kilPulse 0.8s ease-in-out infinite':'none';
        return <path key={`hl${n}`} className={cls} d={wedge(cx,cy,R_BULL*R,R_DBL_O*R,a1,a2)}
          fill={fill} stroke={col} strokeWidth={w} style={{filter:`drop-shadow(0 0 ${o.you?9:6}px ${col})`, animation:anim}}/>;
      })}
      {segAngles.map(([a1],i)=>{ const x1=cx+Math.cos(a1)*R_BULL*R, y1=cy+Math.sin(a1)*R_BULL*R, x2=cx+Math.cos(a1)*R_DBL_O*R, y2=cy+Math.sin(a1)*R_DBL_O*R; return <line key={`sp${i}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke="rgba(0,0,0,0.6)" strokeWidth="1"/>; })}
      <circle cx={cx} cy={cy} r={(R_DBL_O+(R_RIM-R_DBL_O)/2)*R} fill="none" stroke={BG} strokeWidth={(R_RIM-R_DBL_O)*R}/>
      <circle cx={cx} cy={cy} r={R_BULL*R} fill={GREEN} stroke={'#0a3a22'} strokeWidth="2"/>
      <circle cx={cx} cy={cy} r={R_DBULL*R} fill={'#0a3a22'} stroke={GREEN} strokeWidth="1.5"/>
      {SEGMENTS.map((n,i)=>{ const c=-Math.PI/2+i*seg, x=cx+Math.cos(c)*R_NUM*R, y=cy+Math.sin(c)*R_NUM*R; const o=ownerOf(n); const col=o?(o.you?CYAN:RED):'#fff'; return <text key={`n${i}`} x={x} y={y+4} fontFamily="'Press Start 2P', monospace" fontSize="11" fill={col} textAnchor="middle">{n}</text>; })}
    </svg>
  );
};

// Neutral avatar (production = player photo; never a 3-letter abbreviation,
// since two players can share initials). Full name is the textual identifier.
const Avatar = ({ size=24, color=PHOSPHOR }) => (
  <div style={{width:size, height:size, borderRadius:'50%', background:'#1a0030', border:`2px solid ${color}`, display:'flex', alignItems:'flex-end', justifyContent:'center', flexShrink:0, overflow:'hidden'}}>
    <svg width={size*0.8} height={size*0.8} viewBox="0 0 24 24" style={{marginBottom:-1}}>
      <circle cx="12" cy="9" r="4.2" fill={color} opacity="0.85"/>
      <path d="M3.5 22c0-5 3.8-8 8.5-8s8.5 3 8.5 8z" fill={color} opacity="0.85"/>
    </svg>
  </div>
);
const NumBadge = ({ n, col }) => (
  <div style={{width:30, height:30, border:`2px solid ${col}`, background:`${col}1a`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:'#fff', textShadow:`0 0 6px ${col}aa`, flexShrink:0}}>{n}</div>
);
// Owner chip outside the rim — avatar + FULL NAME + number badge + hearts.
const OwnerChip = ({ p, boardSize, you, vulnerable }) => {
  const R = boardSize*0.47, cx=boardSize/2, cy=boardSize/2;
  const a = angleForNum(p.num);
  const rChip = R*1.04 + (you?54:44);
  const x = cx + Math.cos(a)*rChip, y = cy + Math.sin(a)*rChip;
  const col = vulnerable ? RED : you ? CYAN : PHOSPHOR;
  return (
    <div className={vulnerable?'kil-pulse':''} style={{position:'absolute', left:x, top:y, transform:'translate(-50%,-50%)',
      display:'flex', flexDirection:'column', gap:6, padding:you?'9px 12px 10px':'8px 10px',
      background:'rgba(8,0,18,0.95)', border:`${you?3:2}px solid ${col}`, boxShadow:`0 0 ${you?22:12}px ${col}${you?'bb':'55'}`,
      minWidth:you?152:130, animation:vulnerable?'kilPulse 0.9s ease-in-out infinite':'none', zIndex:you?4:2}}>
      {you && <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:CYAN, letterSpacing:1.5, textShadow:`0 0 6px ${CYAN}`}}>★ DITT FELT</div>}
      {vulnerable && <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:RED, letterSpacing:1.5, textShadow:`0 0 6px ${RED}`}}>SISTE LIV</div>}
      <div style={{display:'flex', alignItems:'center', gap:9}}>
        <Avatar size={you?28:24} color={col}/>
        <div style={{flex:1, minWidth:0, fontFamily:'"Inter", system-ui, sans-serif', fontSize:you?15:14, fontWeight:700, color:'#fff', whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{p.name}</div>
        <NumBadge n={p.num} col={col}/>
      </div>
      <div style={{display:'flex', alignItems:'center', gap:10, paddingLeft:2}}>
        <Hearts lives={p.lives} max={p.max} size={you?14:12}/>
        {p.shields>0 && <ShieldTag n={p.shields}/>}
        {p.killer && <span style={{display:'inline-flex', alignItems:'center', gap:4}}><span style={{width:8, height:8, borderRadius:'50%', background:ORANGE, boxShadow:`0 0 5px ${ORANGE}`}}></span><span style={{fontFamily:'"Press Start 2P", monospace', fontSize:7, color:ORANGE, letterSpacing:.5}}>ARMED</span></span>}
      </div>
    </div>
  );
};

// ════════════════════════════════════════════════════════════════
// A · BATTLE BOARD  (recommended)
// ════════════════════════════════════════════════════════════════
// Thin full-width status-key: maps Nº → full name → lives. Color does the
// spatial work on the board; this carries the count + name link (which pure
// color can't). Contained scoreboard strip — not floating boxes.
const PlayersKey = () => (
  <div style={{display:'flex', alignItems:'stretch', borderBottom:`2px solid ${MAGENTA}55`, background:'rgba(0,0,0,0.4)', position:'relative', zIndex:6}}>
    {PLAYERS.map((p,i)=>{
      const you=p.active, vuln=!you&&p.lives===1, col=you?CYAN:RED;
      return (
        <div key={p.handle} className={vuln?'kil-pulse':''} style={{flex:1, display:'flex', alignItems:'center', gap:10, padding:'9px 14px',
          borderLeft:i?`1px solid ${MAGENTA}33`:'none', background:you?`${CYAN}12`:'transparent',
          animation:vuln?'kilPulse 0.9s ease-in-out infinite':'none'}}>
          <div style={{width:32, height:32, border:`2px solid ${col}`, background:`${col}1a`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:'#fff', textShadow:`0 0 6px ${col}aa`, flexShrink:0}}>{p.num}</div>
          <div style={{flex:1, minWidth:0}}>
            <div style={{display:'flex', alignItems:'center', gap:6}}>
              <span style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:14, color:you?'#fff':PHOSPHOR, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{p.name}</span>
              {you && <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:7, color:CYAN, letterSpacing:1, textShadow:`0 0 5px ${CYAN}`}}>DEG</span>}
              {vuln && <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:7, color:RED, letterSpacing:1, textShadow:`0 0 5px ${RED}`}}>SISTE LIV</span>}
            </div>
            <div style={{display:'flex', alignItems:'center', gap:9, marginTop:5}}>
              <Hearts lives={p.lives} max={p.max} size={12}/>
              {p.shields>0 && <ShieldTag n={p.shields}/>}
              {p.killer && <span style={{display:'inline-flex', alignItems:'center', gap:3}}><span style={{width:7, height:7, borderRadius:'50%', background:ORANGE, boxShadow:`0 0 5px ${ORANGE}`}}></span><span style={{fontFamily:'"Press Start 2P", monospace', fontSize:7, color:ORANGE}}>ARMED</span></span>}
            </div>
          </div>
        </div>
      );
    })}
  </div>
);
const CockpitA = () => {
  const boardSize = 760;
  const owners = PLAYERS.map(p => ({ num:p.num, color:p.active?CYAN:PHOSPHOR, vulnerable:!p.active&&p.lives===1, you:p.active }));
  return (
    <Frame>
      <TopBar/>
      <ActiveStrip/>
      <PlayersKey/>
      <div style={{flex:1, position:'relative', display:'flex', alignItems:'center', justifyContent:'center', minHeight:0}}>
        <div style={{position:'absolute', width:boardSize*0.9, height:boardSize*0.9, borderRadius:'50%', boxShadow:`0 0 80px ${MAGENTA}33`, pointerEvents:'none'}}></div>
        <Dartboard size={boardSize} owners={owners}/>
      </div>
      <ActionBar/>
    </Frame>
  );
};

// ════════════════════════════════════════════════════════════════
// B · KILL GRID  (combat cards are the hero)
// ════════════════════════════════════════════════════════════════
const CombatCard = ({ p }) => {
  const you = p.active, vuln = !you && p.lives===1;
  const col = you?CYAN:PHOSPHOR;
  const edge = vuln?RED:col;
  return (
    <div className={vuln?'kil-danger':''} style={{flex:1, position:'relative', border:`2px solid ${edge}`, background:you?`${CYAN}10`:`${PHOSPHOR}06`,
      boxShadow:vuln?`0 0 18px ${RED}aa`:you?`0 0 16px ${CYAN}33`:'none', padding:'14px', display:'flex', flexDirection:'column', gap:11,
      animation:vuln?'kilDanger 1s ease-in-out infinite':'none'}}>
      {you && <div style={{position:'absolute', top:-9, left:14, padding:'2px 8px', background:CYAN, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:8, letterSpacing:1.5}}>▶ YOU</div>}
      {vuln && <div style={{position:'absolute', top:-9, right:14, padding:'2px 8px', background:RED, color:'#fff', fontFamily:'"Press Start 2P", monospace', fontSize:8, letterSpacing:1.5}}>LAST LIFE</div>}
      <div style={{display:'flex', alignItems:'center', gap:11}}>
        <div style={{width:44, height:44, background:BG, border:`2px solid ${col}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:col, textShadow:`0 0 6px ${col}aa`, flexShrink:0}}>{p.handle}</div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:you?'#fff':PHOSPHOR, letterSpacing:1}}>{p.name.toUpperCase()}</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.45)', letterSpacing:2, marginTop:3}}>LAST · {p.last}</div>
        </div>
        <div style={{textAlign:'center'}}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:11, color:'rgba(255,255,255,0.45)', letterSpacing:1}}>Nº</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:30, color:vuln?RED:col, lineHeight:1, textShadow:`0 0 12px ${vuln?RED:col}aa`}}>{p.num}</div>
        </div>
      </div>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', paddingTop:11, borderTop:`1px solid ${edge}44`}}>
        <Hearts lives={p.lives} max={p.max} size={20}/>
        <div style={{display:'flex', alignItems:'center', gap:12}}>
          <ShieldTag n={p.shields}/>
          <ArmedTag killer={p.killer} big/>
        </div>
      </div>
    </div>
  );
};
const CockpitB = () => {
  const boardSize = 300;
  const owners = PLAYERS.map(p => ({ num:p.num, color:p.active?CYAN:PHOSPHOR, vulnerable:!p.active&&p.lives===1, you:p.active }));
  return (
    <Frame>
      <TopBar/>
      <ActiveStrip/>
      <div style={{flex:1, padding:'16px', display:'flex', flexDirection:'column', gap:12, minHeight:0}}>
        {PLAYERS.map(p => <CombatCard key={p.handle} p={p}/>)}
        {/* compact board = input */}
        <div style={{flex:1, minHeight:0, display:'flex', alignItems:'center', justifyContent:'center', gap:18, border:`1px solid ${MAGENTA}33`, background:'#000', position:'relative'}}>
          <div style={{position:'relative', width:boardSize, height:boardSize}}>
            <Dartboard size={boardSize} owners={owners}/>
          </div>
          <div style={{maxWidth:200}}>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:YELLOW, letterSpacing:1, marginBottom:8}}>TAP TO THROW</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.6)', lineHeight:1.45, letterSpacing:1}}>Your <b style={{color:CYAN}}>20</b> arms you · hit a rival's Nº to drain a life · <b style={{color:GREEN}}>BULL</b> = shield.</div>
          </div>
        </div>
      </div>
      <ActionBar/>
    </Frame>
  );
};

// ════════════════════════════════════════════════════════════════
// C · ARENA  (board up top + full-width healthbar roster below)
// ════════════════════════════════════════════════════════════════
const HealthRow = ({ p }) => {
  const you = p.active, vuln = !you && p.lives===1;
  const col = you?CYAN:PHOSPHOR;
  const edge = vuln?RED:col;
  return (
    <div style={{display:'grid', gridTemplateColumns:'54px 1fr auto', alignItems:'center', gap:13, padding:'10px 13px', border:`2px solid ${you?CYAN:`${edge}44`}`, background:you?`${CYAN}10`:'transparent', boxShadow:you?`0 0 12px ${CYAN}33`:'none'}}>
      <div style={{textAlign:'center'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:col, letterSpacing:.5}}>{you?'YOU':p.handle}</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:22, color:vuln?RED:col, lineHeight:1.2, textShadow:`0 0 10px ${vuln?RED:col}aa`}}>{p.num}</div>
      </div>
      <div style={{minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:10}}>
          {/* health bar */}
          <div style={{flex:1, display:'flex', gap:3, height:18}}>
            {Array.from({length:p.max}).map((_,i)=>{
              const filled=i<p.lives;
              return <div key={i} className={vuln&&filled?'kil-pulse':''} style={{flex:1, background:filled?RED:'rgba(255,48,80,0.14)', boxShadow:filled?`0 0 6px ${RED}88`:'none', border:filled?'none':`1px solid ${RED}33`, animation:vuln&&filled?'kilPulse 0.9s ease-in-out infinite':'none'}}></div>;
            })}
          </div>
          <ShieldTag n={p.shields}/>
        </div>
        <div style={{marginTop:7}}><ArmedTag killer={p.killer}/></div>
      </div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.4)', letterSpacing:1, textAlign:'right'}}>LAST<br/><span style={{color:p.last==='MISS'?ORANGE:'rgba(255,255,255,0.7)', fontFamily:'"Press Start 2P", monospace', fontSize:9}}>{p.last}</span></div>
    </div>
  );
};
const CockpitC = () => {
  const boardSize = 360;
  const owners = PLAYERS.map(p => ({ num:p.num, color:p.active?CYAN:PHOSPHOR, vulnerable:!p.active&&p.lives===1, you:p.active }));
  const ordered = [...OPPS, ACTIVE]; // opponents up top, you anchored at the bottom
  return (
    <Frame>
      <TopBar/>
      {/* slim identity (full stat block lives in the roster below) */}
      <div style={{padding:'10px 22px', display:'flex', alignItems:'center', gap:12, background:`linear-gradient(90deg, ${CYAN}1f 0%, transparent 100%)`, borderBottom:`2px solid ${CYAN}`, position:'relative', zIndex:6}}>
        <span style={{color:CYAN, fontFamily:'"Press Start 2P", monospace', fontSize:13, letterSpacing:1.5, textShadow:`0 0 6px ${CYAN}aa`}}>▶ {ACTIVE.name.toUpperCase()}</span>
        <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>DART {ACTIVE.dartIdx+1} / 3</span>
        <div style={{flex:1}}></div>
        <ArmedTag killer={ACTIVE.killer}/>
      </div>
      {/* board = input */}
      <div style={{display:'flex', alignItems:'center', justifyContent:'center', padding:'14px 0 6px', position:'relative'}}>
        <div style={{position:'absolute', width:boardSize*0.96, height:boardSize*0.96, borderRadius:'50%', boxShadow:`0 0 50px ${MAGENTA}2a`, pointerEvents:'none'}}></div>
        <div style={{position:'relative', width:boardSize, height:boardSize}}><Dartboard size={boardSize} owners={owners}/></div>
      </div>
      {/* roster healthbars */}
      <div style={{flex:1, padding:'4px 16px 14px', display:'flex', flexDirection:'column', justifyContent:'flex-end', gap:11, minHeight:0}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginBottom:1}}>ARENA · LIVES + ARMED</div>
        {ordered.map(p => <HealthRow key={p.handle} p={p}/>)}
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
  <div style={{boxSizing:'border-box', width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:14, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · anbefalt retning A</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Killer · battle board</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Hvorfor A</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Input <b style={{color:'#2a251f'}}>er</b> hele brettet (samme som X01) — så brettet må være helt og stort. <b style={{color:'#2a251f'}}>Farge gjør jobben:</b> ditt tall lyser cyan (mest luminøst), alle fiender er røde (= mål du kan angripe), og den/de på siste liv blinker rødt. Ingen flytende chips presser brettet ned — kun en tynn status-key over brettet kobler tall→navn→liv. Du ser «hva er mitt» og «hvem kan jeg ta ut» i ett blikk. B (kill-grid) er mest dramatisk men presser brettet ned; C (arena) splitter brett + healthbars.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Farger (per rolle)</div>
      <SpecRow zone="Aktiv spiller (deg) · ditt tall" val="#00E5FF" hex={CYAN}/>
      <SpecRow zone="Fiender · alle felter (blink = 1 liv)" val="#FF3050" hex={RED}/>
      <SpecRow zone="Liv (hjerter) · fare · siste liv" val="#FF3050" hex={RED}/>
      <SpecRow zone="KILLER / armert" val="#FF7A00" hex={ORANGE}/>
      <SpecRow zone="Shields (bull)" val="#3DFF8E" hex={GREEN}/>
      <SpecRow zone="Topbar-label / ditt-Nº-label" val="#FFD200" hex={YELLOW}/>
      <SpecRow zone="Ramme + glow + bane-linjer" val="#FF00AA" hex={MAGENTA}/>
      <SpecRow zone="BG + frame + bull-kjerne" val="#0A0014" hex={BG}/>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Input + kamp-logikk</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Tap segment → <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>engine.applyHit(segment, multiplier)</code> (samme brett som X01). Treff <b style={{color:'#2a251f'}}>eget tall</b> = bli KILLER (ingen skade). Som killer: treff <b style={{color:'#2a251f'}}>annens tall</b> = -1 liv (×N ved multiplyHits); shields absorberes først. <b style={{color:'#2a251f'}}>BULL</b> = +1 shield (D-bull +3). Eget tall som killer = self-hit (-1 eget liv). Sist i live vinner.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Arcade-cockpit','Erstatt classic AppBar + Material-brett med DOSSEDART-chrome: ArcadeFrame (CRT), topbar, active-strip, brett, action-bar. Gjenbruk X01-brettet (DossedartX01Dartboard / TWILIGHT) 1:1.'],
        ['2','Farge gjør jobben — ingen flytende bokser','Brettet er fullt (~760) og rent. Hvert eid tall fargelegges direkte i wedge-en: ditt = lys cyan (pulser, mest luminøst), alle fiender = røde (mål), siste liv = blinker rødt, eliminert = mørklagt + strøket tall. Ingen chips rundt rim-en — brettet behøver ikke krympes.'],
        ['3','Tynn status-key (navn + liv)','Farge kan ikke vise antall liv eller koble tall→navn alene, så en tynn full-bredde key over brettet lister hver spiller: farget Nº-badge + FULLT NAVN (ikke forkortelse — flere kan dele initialer) + hjerter + armert/shield. Din rad er cyan. Ikke flytende — en kontainert status-stripe.'],
        ['4','Én farge-logikk','Du=cyan (eneste cyan på brettet), alle fiender=rød (siste liv blinker), shields=grønn, armert=oransje (i key), label=gul. Ingen per-spiller-rainbow.'],
        ['5','Config-aware','Topbar viser LIVES + SHIELDS/×HITS når på. Assignment-fasen (throw-to-pick) gjenbruker brettet med «P{n} velg tall»-prompt; tatt/bull/miss → kast igjen.'],
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
        <b>Konsistens:</b> samme chrome + farge-prinsipp som X01/Cricket/ATC. Killer deler brett med X01 (input er identisk) — det nye er kamp-laget (eierskap, liv, armert, shields) lagt oppå. Hjerter = liv, grønn skjold = shields, oransje = armert.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const KillerCockpit = () => (
  <DCSection
    id="killer-directions"
    title="Killer — cockpit (3 kamp-tilstand retninger)"
    subtitle="Killer er PvP-eliminering: hver spiller eier et tall (1–20), treffer sitt eget for å bli KILLER (armert), og angriper så motstandernes tall for å tappe liv (shields absorberer; bull gir shields). Input er hele brettet — som X01. Det åpne spørsmålet er hvordan kamp-rosteret (tall · liv · armert · shields) leses mot brettet. Anbefalt: A · battle board — brettet er helt + kamp-tilstand ligger som farge på selve brettet + en tynn status-key.">
    <DCArtboard id="kil-a" label="A · Battle board  ← anbefalt" width={K_W} height={K_H}><CockpitA/></DCArtboard>
    <DCArtboard id="kil-b" label="B · Kill grid (kamp-kort)" width={K_W} height={K_H}><CockpitB/></DCArtboard>
    <DCArtboard id="kil-c" label="C · Arena (brett + healthbars)" width={K_W} height={K_H}><CockpitC/></DCArtboard>
    <DCArtboard id="kil-spec" label="Implementasjon · spec + tokens (retning A)" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.KillerCockpit = KillerCockpit;

// ── Locked final — direction A (battle board), refined ──────────
const KillerCockpitFinal = () => (
  <DCSection
    id="killer-final"
    title="Killer cockpit — final (battle board)"
    subtitle="Valgt retning A, raffinert til «farge gjør jobben»: brettet er tilbake i full størrelse (760) og rent — ingen flytende chips. Eierskap vises i selve wedge-en: ditt tall lyser cyan (mest luminøst), alle fiender er røde, og siste liv blinker rødt. En tynn status-key over brettet kobler tall→fullt navn→liv (det farge ikke kan vise alene).">
    <DCArtboard id="kilf-cockpit" label="Cockpit · Killer · battle board" width={K_W} height={K_H}><CockpitA/></DCArtboard>
    <DCArtboard id="kilf-spec" label="Implementasjon · spec + tokens" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.KillerCockpitFinal = KillerCockpitFinal;
