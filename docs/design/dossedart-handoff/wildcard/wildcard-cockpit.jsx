// DOSSEDART — WILDCARD cockpit · chaos mode
// ───────────────────────────────────────────────────────────────
// Points race sabotaged by chaos. Reuses the DOSSEDART cockpit skeleton
// (Frame + scanlines, TopBar, ActionBar) and the LOCKED CRT board — WILDCARD
// adds only DIM STATES on segments (the board doubles as the live rulebook
// for the active restriction). Everything else in the skeleton is unchanged.
//
// What is NEW for WILDCARD (design effort here):
//   • CHAOS METER (0–10) — always visible, big & dramatic; the centerpiece
//     (idle / rising / max looks)
//   • modifier announcement pre-turn overlay ("oh no")
//   • modifier badge + dimmed-board restriction state
//   • THE WINDOW display (WINDOW: 3–9 · ALL DARTS MUST SCORE)
//   • bull choice dialog (chaos ±1 / ±3)
//   • joker reveal moment (signature)
//   • instant-event feedback (swap / steal / freeze)
//   • CUT! and REWIND treatments
//   • meter-at-max permanent danger styling · winner
// UI strings English (Norwegian-string guard). Terminology: CHAOS METER,
// THE WINDOW, WINDOW PRIZE, HOLY TRINITY, joker, CUT!, REWIND.

const WC_W = 820, WC_H = 1300; // taller (~16:10 tablet) so the richer scorecard fits WITHOUT shrinking the 760px board

const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', BG='#0a0014', SURFACE='#1a0030',
      PHOSPHOR='#D9D2C2', PURPLE='#B15CFF';

// chaos-level → heat colour (per segment threshold)
const chaosColor = (lvl) => lvl<=2 ? CYAN : lvl<=4 ? GREEN : lvl<=6 ? YELLOW : lvl<=8 ? ORANGE : RED;

// ════════════════════════════════════════════════════════════════
// CRT BOARD w/ DIM SUPPORT — copied from gotcha, dim(number) darkens
// a whole wedge (single + ring) to near-black; the WILDCARD addition.
// ════════════════════════════════════════════════════════════════
const WC_SECTORS = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5];
const WC_DBULL=0.06, WC_BULL=0.14, WC_SINGLE_I=0.46, WC_TRIPLE=0.64, WC_SINGLE_O=0.86, WC_DOUBLE=1.0, WC_NUM=1.06;
const WC_TAU=Math.PI*2, WC_SEG=WC_TAU/20;
const WC_BOARD = { surround:'#05000e', base:'#05000e', darkSingle:'#190b32', lightSingle:'#3c2472',
  ringDark:'#e637a8', ringLight:'#2fc4dd', bullOuter:'#FFD200', bullStroke:'#FF7A00', bullInner:'#FF3050', num:'#fff' };
const DIM_SINGLE='#0b0618', DIM_RING='#140a24', DIM_NUM='rgba(217,210,194,0.22)';

function wcWedge(cx,cy,rIn,rOut,a1,a2){
  const px=(r,a)=>cx+r*Math.cos(a), py=(r,a)=>cy+r*Math.sin(a);
  const large=(a2-a1)>Math.PI?1:0;
  return `M ${px(rIn,a1)} ${py(rIn,a1)} L ${px(rOut,a1)} ${py(rOut,a1)} A ${rOut} ${rOut} 0 ${large} 1 ${px(rOut,a2)} ${py(rOut,a2)} L ${px(rIn,a2)} ${py(rIn,a2)} A ${rIn} ${rIn} 0 ${large} 0 ${px(rIn,a1)} ${py(rIn,a1)} Z`;
}
function wcBoardSVG(size, o, isDim){
  const cx=size/2, cy=size/2, R=size*0.40;
  let s=`<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" style="display:block">`;
  s+=`<circle cx="${cx}" cy="${cy}" r="${R*1.14}" fill="${o.surround}"/>`;
  s+=`<circle cx="${cx}" cy="${cy}" r="${R*WC_DOUBLE}" fill="${o.base}"/>`;
  for(let i=0;i<20;i++){
    const n=WC_SECTORS[i];
    const a1=-Math.PI/2+i*WC_SEG-WC_SEG/2, a2=a1+WC_SEG;
    const dim = isDim && isDim(n);
    const isDark=(i%2===0);
    const single= dim?DIM_SINGLE:(isDark?o.darkSingle:o.lightSingle);
    const ring  = dim?DIM_RING:(isDark?o.ringDark:o.ringLight);
    s+=`<path d="${wcWedge(cx,cy,WC_BULL*R,WC_SINGLE_I*R,a1,a2)}" fill="${single}"/>`;
    s+=`<path d="${wcWedge(cx,cy,WC_SINGLE_I*R,WC_TRIPLE*R,a1,a2)}" fill="${ring}"/>`;
    s+=`<path d="${wcWedge(cx,cy,WC_TRIPLE*R,WC_SINGLE_O*R,a1,a2)}" fill="${single}"/>`;
    s+=`<path d="${wcWedge(cx,cy,WC_SINGLE_O*R,WC_DOUBLE*R,a1,a2)}" fill="${ring}"/>`;
  }
  s+=`<circle cx="${cx}" cy="${cy}" r="${WC_BULL*R}" fill="${o.bullOuter}" stroke="${o.bullStroke}" stroke-width="2.5"/>`;
  s+=`<circle cx="${cx}" cy="${cy}" r="${WC_DBULL*R}" fill="${o.bullInner}"/>`;
  const fs=size*0.04;
  WC_SECTORS.forEach((n,i)=>{ const c=-Math.PI/2+i*WC_SEG, x=cx+Math.cos(c)*WC_NUM*R, y=cy+Math.sin(c)*WC_NUM*R; const dim=isDim&&isDim(n); s+=`<text x="${x}" y="${y+fs*0.36}" font-family="'Press Start 2P',monospace" font-size="${fs}" fill="${dim?DIM_NUM:o.num}" text-anchor="middle">${n}</text>`; });
  return s+`</svg>`;
}
const WCBoard = ({ size=300, isDim, tint }) => (
  <div style={{position:'relative', width:size, height:size}}>
    <div style={{filter:`drop-shadow(0 0 6px ${(tint||MAGENTA)}44) drop-shadow(0 0 3px ${CYAN}33)`}}
         dangerouslySetInnerHTML={{__html: wcBoardSVG(size, WC_BOARD, isDim)}}/>
    <div style={{position:'absolute', inset:0, pointerEvents:'none', background:'repeating-linear-gradient(0deg,rgba(0,0,0,0) 0px,rgba(0,0,0,0) 3px,rgba(0,0,0,0.26) 4px,rgba(0,0,0,0) 5px)'}}/>
    <div style={{position:'absolute', inset:0, pointerEvents:'none', borderRadius:'50%', background:'radial-gradient(ellipse 56% 42% at 50% 28%,rgba(255,255,255,0.10),transparent 60%)'}}/>
    <div style={{position:'absolute', inset:0, pointerEvents:'none', borderRadius:'50%', boxShadow:`inset 0 0 60px 10px rgba(0,0,0,0.7)${tint?`, inset 0 0 90px 20px ${tint}33`:''}`}}/>
  </div>
);

// ── shell chrome ─────────────────────────────────────────────────
const wcScan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const WCFrame = ({ children, danger }) => (
  <div style={{width:WC_W, height:WC_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:wcScan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {danger && <div style={{position:'absolute', inset:0, pointerEvents:'none', zIndex:4, boxShadow:`inset 0 0 120px 20px ${RED}33`, animation:'wcDanger 1.4s infinite'}}></div>}
    {children}
  </div>
);
const WCTopBar = ({ round, rounds }) => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>🃏 WILDCARD</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>ROUND {round}/{rounds}</div>
  </div>
);
const WCActionBar = () => (
  <div style={{padding:'12px 16px 16px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:10, zIndex:6}}>
    <div style={{flex:1, padding:'14px', border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:2, padding:'14px', background:ORANGE, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:BG, letterSpacing:2, textAlign:'center', boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:1, padding:'14px', border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5, textAlign:'center'}}>⋯ MENU</div>
  </div>
);

// ════════════════════════════════════════════════════════════════
// CHAOS METER — the centerpiece. 10 heat segments + big level number.
// look: idle (calm) / rising / max (danger pulse).
// ════════════════════════════════════════════════════════════════
const ChaosMeter = ({ level }) => {
  const c = chaosColor(level);
  const max = level>=9;
  const label = level===0 ? 'DORMANT' : level<=2 ? 'MILD' : level<=4 ? 'BUBBLING' : level<=6 ? 'SPICY' : level<=8 ? 'WILD' : 'TOTAL CHAOS';
  return (
    <div style={{margin:'12px 16px 0', padding:'12px 16px 13px', position:'relative',
      border:`2px solid ${c}`, background:`linear-gradient(180deg, ${c}1c 0%, ${c}06 100%)`,
      boxShadow:`0 0 20px ${c}55${max?`, inset 0 0 24px ${RED}33`:''}`,
      animation: max?'wcMaxPulse 1.1s infinite':'none'}}>
      <div style={{display:'flex', alignItems:'center', gap:12}}>
        <div style={{flexShrink:0}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:c, letterSpacing:2, textShadow:`0 0 6px ${c}`}}>CHAOS</div>
          <div style={{display:'flex', alignItems:'baseline', gap:3, marginTop:5}}>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:42, color:c, lineHeight:0.9, textShadow:`0 0 16px ${c}`, letterSpacing:-2}}>{level}</span>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:'rgba(255,255,255,0.4)'}}>/10</span>
          </div>
        </div>
        <div style={{flex:1, minWidth:0}}>
          {/* 10 heat segments */}
          <div style={{display:'flex', gap:4, height:26}}>
            {Array.from({length:10}).map((_,i)=>{
              const n=i+1, on=n<=level, lead=n===level;
              const sc=chaosColor(n);
              return <div key={i} style={{flex:1, background:on?sc:'rgba(255,255,255,0.07)',
                border:`1px solid ${on?sc:'rgba(255,255,255,0.12)'}`,
                boxShadow: on?(lead?`0 0 12px ${sc}, inset 0 0 6px #fff6`:`0 0 5px ${sc}88`):'none',
                animation: lead&&max?'wcSegPulse 0.7s infinite':'none'}}/>;
            })}
          </div>
          <div style={{display:'flex', justifyContent:'space-between', marginTop:6}}>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:c, letterSpacing:1.5, textShadow:`0 0 6px ${c}88`}}>{label}</span>
            <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>{max?'EVENTS EVERY TURN · 2 JOKERS':`events @ ${[0,10,10,25,25,45,45,70,70,100,100][level]}%`}</span>
          </div>
        </div>
      </div>
    </div>
  );
};

// ── modifier badge on the active card ────────────────────────────
const ModBadge = ({ mod }) => mod ? (
  <div style={{display:'inline-flex', alignItems:'center', gap:8, padding:'5px 11px', background:`${PURPLE}22`, border:`2px solid ${PURPLE}`, boxShadow:`0 0 12px ${PURPLE}66`}}>
    <span style={{fontSize:14}}>{mod.icon}</span>
    <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'#e9d4ff', letterSpacing:1, textShadow:`0 0 6px ${PURPLE}`}}>{mod.name}</span>
  </div>
) : null;

// ── per-dart breakdown — richer than plain pips: each dart's value
//    (T19 / 20 / DBL / — miss) plus the live "DART n/3" counter. ──
const DartSlots = ({ darts=[], accent }) => {
  const thrown = darts.filter(d=>d!=null && d!=='').length;
  const label = thrown<3 ? thrown+1 : 3;
  return (
    <div style={{display:'flex', alignItems:'center', gap:6, marginTop:9}}>
      {[0,1,2].map(i=>{
        const v = darts[i];
        const has = v!=null && v!=='';
        const cur = i===thrown && thrown<3;
        const miss = v==='—';
        return (
          <div key={i} style={{minWidth:44, height:32, padding:'0 6px', display:'flex', alignItems:'center', justifyContent:'center',
            border:`2px ${has||cur?'solid':'dashed'} ${has?(miss?'rgba(255,255,255,0.28)':accent):(cur?accent:'rgba(255,255,255,0.16)')}`,
            background: has&&!miss?`${accent}1e`:'transparent',
            boxShadow: has&&!miss?`0 0 8px ${accent}55`:(cur?`0 0 10px ${accent}66`:'none'),
            animation: cur?'wcSegPulse 0.9s infinite':'none'}}>
            <span style={{fontFamily:'"VT323", monospace', fontSize:19, letterSpacing:1, color: has?(miss?'rgba(255,255,255,0.45)':'#fff'):(cur?accent:'rgba(255,255,255,0.28)')}}>{has?v:(cur?'▸':'·')}</span>
          </div>
        );
      })}
      <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:1, marginLeft:2}}>DART {label}/3</span>
    </div>
  );
};

// ── THIS TURN — the dominant element: what THIS player must throw
//    this round (restriction / window / open). Prioritised over the
//    other players' scores, per the brief. ────────────────────────
const wcDirective = (p, mod, win) => {
  if (win) return { icon:'🎯', color:PURPLE, head:`LAND TOTAL ${win.lo}–${win.hi}`, sub:'ALL 3 DARTS MUST SCORE · INSIDE → +100 PRIZE' };
  if (mod)  return { icon:mod.icon, color:PURPLE, head:mod.name, sub:mod.desc };
  return { icon:'▶', color:p.accent, head:'OPEN THROW · SCORE MAX', sub:'No restriction this turn — pile on points' };
};
const ThrowDirective = ({ d }) => (
  <div style={{marginTop:13, position:'relative', border:`3px solid ${d.color}`,
    background:`linear-gradient(180deg, ${d.color}26 0%, ${d.color}0b 100%)`,
    boxShadow:`0 0 20px ${d.color}66, inset 0 0 22px ${d.color}18`, padding:'14px 16px'}}>
    <div style={{position:'absolute', top:-9, left:14, padding:'3px 9px', background:d.color, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:8, letterSpacing:2, boxShadow:`0 0 8px ${d.color}aa`}}>THIS TURN</div>
    <div style={{display:'flex', alignItems:'center', gap:14}}>
      <span style={{fontSize:34, lineHeight:1, flexShrink:0}}>{d.icon}</span>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:18, color:'#fff', letterSpacing:1, lineHeight:1.18, textShadow:`0 0 12px ${d.color}, 0 0 4px ${d.color}`}}>{d.head}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:19, color:'rgba(255,255,255,0.78)', letterSpacing:1, marginTop:6}}>{d.sub}</div>
      </div>
    </div>
  </div>
);

// ── standings — DEMOTED to a compact strip (secondary to THIS TURN).
//    Still ranks everyone + flags 👑 leader / ▽ last (the events target
//    them) and shows the Robin-Hood steal/robbed flags. ─────────────
const wcRank = (players) => {
  const sorted = [...players].sort((a,b)=>b.total-a.total);
  return { sorted, lead: sorted[0].total, last: sorted[sorted.length-1].total };
};
const Standings = ({ players }) => {
  const { sorted, lead, last } = wcRank(players);
  return (
    <div style={{marginTop:12}}>
      <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:6}}>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:7, color:'rgba(255,255,255,0.35)', letterSpacing:2}}>STANDINGS</span>
        <div style={{flex:1, height:1, background:'rgba(255,255,255,0.1)'}}/>
      </div>
      <div style={{display:'flex', gap:8}}>
        {sorted.map((p,idx)=>{
          const c = p.accent;
          const isLead = p.total===lead, isLast = p.total===last && lead!==last;
          return (
            <div key={p.handle} style={{flex:1, minWidth:0, display:'flex', alignItems:'center', gap:7,
              padding:'6px 9px', border:`1px solid ${p.active?c:'rgba(255,255,255,0.12)'}`,
              background:p.active?`${c}12`:'transparent', opacity:p.active?1:0.72}}>
              <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:isLead?YELLOW:'rgba(255,255,255,0.35)'}}>{idx+1}</span>
              <span style={{width:7, height:7, background:c, boxShadow:`0 0 5px ${c}`, flexShrink:0}}/>
              <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'#fff', letterSpacing:0.5, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{p.name.toUpperCase()}</span>
              <span style={{marginLeft:'auto', fontFamily:'"VT323", monospace', fontSize:20, color:c, lineHeight:1, textShadow:`0 0 6px ${c}66`}}>{p.total}</span>
              {p.flag
                ? <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:7, letterSpacing:0.5, color:p.flag.type==='good'?GREEN:RED, border:`1px solid ${p.flag.type==='good'?GREEN:RED}`, padding:'2px 4px', flexShrink:0}}>{p.flag.text}</span>
                : (isLead ? <span style={{fontSize:12, flexShrink:0}}>👑</span> : (isLast ? <span style={{fontSize:12, flexShrink:0}}>▽</span> : null))}
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ── SCORECARD — the ONE surface that grows. Active-player detail on
//    top (avatar · per-dart breakdown · TURN · GAME + rank/to-lead),
//    full standings below. Board size is untouched; all new WILDCARD
//    data lives here. Modifier badge + THE WINDOW slot in between. ──
const WCScoreCard = ({ players, round, rounds, mod, window: win }) => {
  const p = players.find(x=>x.active) || players[0];
  const { sorted, lead } = wcRank(players);
  const rank = sorted.findIndex(x=>x.handle===p.handle)+1;
  const delta = p.total - lead;
  const c = p.accent, themed = mod?PURPLE:c;
  return (
    <div style={{position:'relative', margin:'12px 16px 0', border:`3px solid ${themed}`,
      background:`linear-gradient(180deg, ${themed}16 0%, ${themed}05 100%)`,
      boxShadow:`0 0 18px ${themed}45`, padding:'13px 16px 14px'}}>
      <div style={{position:'absolute', top:-9, left:16, padding:'3px 9px', background:themed, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:9, letterSpacing:1.5, boxShadow:`0 0 8px ${themed}aa`}}>▶ SCORECARD · R{round}/{rounds}</div>
      <div style={{display:'flex', alignItems:'center', gap:13}}>
        <div style={{width:46, height:46, background:BG, border:`3px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:c, textShadow:`0 0 8px ${c}aa`, flexShrink:0, boxShadow:`0 0 12px ${c}55`}}>{p.handle}</div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:15, color:'#fff', letterSpacing:2, lineHeight:1}}>{p.name.toUpperCase()}</div>
          <DartSlots darts={p.darts||[]} accent={c}/>
        </div>
        <div style={{textAlign:'right', flexShrink:0, marginRight:13}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>TURN</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:30, color:c, lineHeight:1, textShadow:`0 0 12px ${c}aa`, marginTop:4}}>{p.turn}</div>
        </div>
        <div style={{textAlign:'right', flexShrink:0, borderLeft:'2px solid rgba(255,255,255,0.12)', paddingLeft:14}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:YELLOW, letterSpacing:1}}>GAME</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:32, color:'#fff', lineHeight:1, textShadow:`0 0 12px ${YELLOW}66`, marginTop:4}}>{p.total}</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.55)', letterSpacing:1, marginTop:5}}>#{rank} · {delta<0?`${delta} TO LEAD`:'LEADER'}</div>
        </div>
      </div>
      <ThrowDirective d={wcDirective(p, mod, win)}/>
      <Standings players={players}/>
    </div>
  );
};

// ── moment overlay ───────────────────────────────────────────────
const WCOverlay = ({ tint, children }) => (
  <div style={{position:'absolute', inset:0, zIndex:8, display:'flex', alignItems:'center', justifyContent:'center',
    background:`radial-gradient(ellipse at center, ${tint}26 0%, rgba(5,0,14,0.9) 72%)`, backdropFilter:'blur(3px)'}}>
    {children}
  </div>
);

// ── bull choice dialog (state 5) ─────────────────────────────────
const BullDialog = ({ delta }) => (
  <WCOverlay tint={YELLOW}>
    <div style={{width:560, background:BG, border:`3px solid ${YELLOW}`, boxShadow:`0 0 32px ${YELLOW}66`, padding:'26px 28px'}}>
      <div style={{textAlign:'center'}}>
        <div style={{fontSize:32}}>🎯</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:20, color:YELLOW, letterSpacing:2, textShadow:`0 0 12px ${YELLOW}`, marginTop:10}}>{delta===3?'DOUBLE BULL · 50':'BULL · 25'}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:'#fff', letterSpacing:1, marginTop:8}}>YOU CONTROL THE CHAOS — CHOOSE ±{delta}</div>
      </div>
      <div style={{display:'flex', gap:14, marginTop:22}}>
        <div style={{flex:1, padding:'18px 0', textAlign:'center', border:`2px solid ${RED}`, background:`${RED}18`, boxShadow:`0 0 16px ${RED}44`}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:26, color:RED, textShadow:`0 0 12px ${RED}`}}>▲ +{delta}</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'#ff9db0', letterSpacing:1, marginTop:8}}>IGNITE · MORE CHAOS</div>
        </div>
        <div style={{flex:1, padding:'18px 0', textAlign:'center', border:`2px solid ${CYAN}`, background:`${CYAN}18`, boxShadow:`0 0 16px ${CYAN}44`}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:26, color:CYAN, textShadow:`0 0 12px ${CYAN}`}}>▼ −{delta}</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'#a9ecff', letterSpacing:1, marginTop:8}}>CALM · COOL IT DOWN</div>
        </div>
      </div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.45)', letterSpacing:1, textAlign:'center', marginTop:16}}>LEADERS COOL · TRAILERS IGNITE · BULL SCORES EITHER WAY</div>
    </div>
  </WCOverlay>
);

// ── generic dialog popup (state-5 style) — used for announce/joker/event/cut/rewind/winner ──
const WCDialog = ({ accent, icon, title, titleSize=46, spin, children }) => (
  <WCOverlay tint={accent}>
    <div style={{width:600, maxWidth:'86%', background:BG, border:`3px solid ${accent}`, boxShadow:`0 0 34px ${accent}77, inset 0 0 30px ${accent}18`, padding:'26px 30px 28px', textAlign:'center'}}>
      <div style={{fontSize:42, lineHeight:1, animation: spin?'wcSpin 1.1s linear infinite':'wcPop 0.5s ease-out'}}>{icon}</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:titleSize, color:accent, letterSpacing:2, textShadow:`0 0 22px ${accent}, 4px 4px 0 ${MAGENTA}`, marginTop:12, lineHeight:1.12}}>{title}</div>
      {children}
    </div>
  </WCOverlay>
);
const WCMiss = ({ pos }) => (
  <div style={{position:'absolute', ...pos, fontFamily:'"Press Start 2P", monospace', fontSize:9, color:MAGENTA, opacity:0.3, letterSpacing:1, pointerEvents:'none'}}>✗ MISS</div>
);

// ════════════════════════════════════════════════════════════════
// COCKPIT
// ════════════════════════════════════════════════════════════════
const WCCockpit = ({ s }) => {
  const max = s.chaos>=9;
  const active = s.players.find(p=>p.active) || s.players[0];
  return (
    <WCFrame danger={max}>
      <WCTopBar round={s.round} rounds={s.rounds}/>
      <ChaosMeter level={s.chaos}/>
      <WCScoreCard players={s.players} round={s.round} rounds={s.rounds} mod={s.mod} window={s.window ? {lo:s.window[0], hi:s.window[1]} : null}/>
      {/* board — full size (760), as large as the X01/Gotcha board */}
      <div style={{flex:1, display:'flex', alignItems:'center', justifyContent:'center', minHeight:0, position:'relative', zIndex:3, margin:'8px 0'}}>
        <div style={{position:'absolute', width:740, height:740, borderRadius:'50%', boxShadow:`0 0 70px ${(max?RED:MAGENTA)}3a`, pointerEvents:'none'}}></div>
        <WCMiss pos={{top:2, left:22}}/>
        <WCMiss pos={{top:2, right:22}}/>
        <WCMiss pos={{bottom:2, left:22}}/>
        <WCMiss pos={{bottom:2, right:22}}/>
        <WCBoard size={760} isDim={s.dim} tint={max?RED:null}/>
      </div>

      {/* overlays */}
      {s.overlay==='announce' && (
        <WCDialog accent={PURPLE} icon={s.mod.icon} title={s.mod.name} titleSize={34}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'#e9d4ff', letterSpacing:5, marginTop:6}}>▓ CHAOS STRIKES ▓</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:21, color:'rgba(255,255,255,0.85)', letterSpacing:1, marginTop:12, lineHeight:1.3}}>{s.mod.desc}</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, marginTop:16, textShadow:`0 0 8px ${YELLOW}88`}}>{active.name.toUpperCase()}'S TURN ONLY</div>
        </WCDialog>
      )}
      {s.overlay==='joker' && (
        <WCDialog accent={GREEN} icon="🃏" title="JOKER!" titleSize={48}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:23, color:'#fff', letterSpacing:2, marginTop:14}}>HIDDEN NUMBER <b style={{color:GREEN, fontFamily:'"Press Start 2P", monospace', fontSize:17}}>{s.jokerNum}</b> DETONATES</div>
          <div style={{display:'flex', gap:14, justifyContent:'center', marginTop:18}}>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:CYAN, letterSpacing:1, padding:'8px 14px', border:`2px solid ${CYAN}`, boxShadow:`0 0 10px ${CYAN}44`}}>METER +2</span>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:ORANGE, letterSpacing:1, padding:'8px 14px', border:`2px solid ${ORANGE}`, boxShadow:`0 0 10px ${ORANGE}44`}}>INSTANT EVENT ▶</span>
          </div>
        </WCDialog>
      )}
      {s.overlay==='event' && (
        <WCDialog accent={ORANGE} icon={s.event.icon} title={s.event.name} titleSize={36}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:23, color:'#fff', letterSpacing:1, marginTop:14, lineHeight:1.3}}>{s.event.detail}</div>
        </WCDialog>
      )}
      {s.overlay==='cut' && (
        <WCDialog accent={RED} icon="✂️" title="CUT!" titleSize={56}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:23, color:'#fff', letterSpacing:2, marginTop:14, lineHeight:1.3}}>ROUND ENDS NOW · PLAYERS YET TO THROW LOSE THEIR TURN</div>
        </WCDialog>
      )}
      {s.overlay==='rewind' && (
        <WCDialog accent={CYAN} icon="⟲" title="REWIND" titleSize={48} spin>
          <div style={{fontFamily:'"VT323", monospace', fontSize:23, color:'#fff', letterSpacing:2, marginTop:14}}>ROUND {s.round} SCORES WIPED · RESTART FROM FIRST PLAYER</div>
          <div style={{display:'flex', gap:8, justifyContent:'center', marginTop:16}}>
            {['48','120','0','—'].map((v,i)=>(<span key={i} style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.4)', textDecoration:'line-through', letterSpacing:1}}>{v}</span>))}
          </div>
        </WCDialog>
      )}
      {s.overlay==='bull' && <BullDialog delta={s.bullDelta}/>}
      {s.overlay==='winner' && (
        <WCDialog accent={YELLOW} icon="★ ★ ★" title={<React.Fragment>WILDCARD<br/>WINNER</React.Fragment>} titleSize={44}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:19, color:'#fff', letterSpacing:2, marginTop:16}}>{active.name.toUpperCase()} · {active.total} PTS</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:22, color:CYAN, letterSpacing:2, marginTop:10}}>SURVIVED THE CHAOS</div>
        </WCDialog>
      )}
      <WCActionBar/>
    </WCFrame>
  );
};

// ── modifiers / events ───────────────────────────────────────────
const MOD_EVENS   = { name:'ONLY EVENS',   icon:'⬛', desc:'Only even numbers score this turn', dim:(n)=>n%2!==0 };
const MOD_WINDOW  = { name:'THE WINDOW',    icon:'🎯', desc:'Land your turn total inside the window' };
const MOD_TRINITY = { name:'HOLY TRINITY',  icon:'✨', desc:'Score exactly 26 (20-5-1) → +100 bonus' };

// ── scenarios ────────────────────────────────────────────────────
const P = (name, handle, accent, total, extra={}) => ({ name, handle, accent, total, ...extra });

const WC_STATES = {
  default:  { round:4, rounds:10, chaos:3, players:[
    P('Jonas','JON',CYAN,214,{active:true, turn:41, darts:['20','T7',null]}),
    P('Kari','KAR',MAGENTA,255), P('Per','PER',GREEN,188) ] },
  announce: { round:4, rounds:10, chaos:3, mod:MOD_EVENS, overlay:'announce', players:[
    P('Jonas','JON',CYAN,214,{active:true, turn:0, darts:[]}),
    P('Kari','KAR',MAGENTA,255), P('Per','PER',GREEN,188) ] },
  restrict: { round:4, rounds:10, chaos:4, mod:MOD_EVENS, dim:MOD_EVENS.dim, players:[
    P('Jonas','JON',CYAN,214,{active:true, turn:20, darts:['20',null,null]}),
    P('Kari','KAR',MAGENTA,255), P('Per','PER',GREEN,188) ] },
  window:   { round:5, rounds:10, chaos:6, mod:MOD_WINDOW, window:[3,9], players:[
    P('Jonas','JON',CYAN,255,{active:true, turn:0, darts:[]}),
    P('Kari','KAR',MAGENTA,268), P('Per','PER',GREEN,231) ] },
  bull:     { round:5, rounds:10, chaos:6, overlay:'bull', bullDelta:3, players:[
    P('Jonas','JON',CYAN,268,{active:true, turn:50, darts:['DBL',null,null]}),
    P('Kari','KAR',MAGENTA,268), P('Per','PER',GREEN,231) ] },
  joker:    { round:6, rounds:10, chaos:8, jokerNum:14, overlay:'joker', players:[
    P('Jonas','JON',CYAN,288,{active:true, turn:71, darts:['T19','14',null]}),
    P('Kari','KAR',MAGENTA,288), P('Per','PER',GREEN,260) ] },
  event:    { round:6, rounds:10, chaos:8, overlay:'event',
              event:{ name:'ROBIN HOOD', icon:'🏹', detail:'Steal 50 from the leader — KARI 288 → 238' },
              players:[
    P('Jonas','JON',CYAN,338,{active:true, turn:71, darts:['T19','14',null], flag:{type:'good', text:'+50 STEAL'}}),
    P('Kari','KAR',MAGENTA,238,{flag:{type:'bad', text:'−50 ROBBED'}}), P('Per','PER',GREEN,260) ] },
  cut:      { round:7, rounds:10, chaos:9, overlay:'cut', players:[
    P('Jonas','JON',CYAN,338), P('Kari','KAR',MAGENTA,300),
    P('Per','PER',GREEN,288,{active:true, turn:38, darts:['T7','17','—']}) ] },
  rewind:   { round:7, rounds:10, chaos:9, overlay:'rewind', players:[
    P('Jonas','JON',CYAN,338,{active:true, turn:0, darts:[]}),
    P('Kari','KAR',MAGENTA,300), P('Per','PER',GREEN,288) ] },
  maxmeter: { round:8, rounds:10, chaos:10, mod:MOD_TRINITY, players:[
    P('Jonas','JON',CYAN,372,{active:true, turn:63, darts:['T20','3',null]}),
    P('Kari','KAR',MAGENTA,358), P('Per','PER',GREEN,320) ] },
  winner:   { round:10, rounds:10, chaos:7, overlay:'winner', players:[
    P('Jonas','JON',CYAN,432,{active:true, turn:60, darts:['T20',null,null]}),
    P('Kari','KAR',MAGENTA,400), P('Per','PER',GREEN,366) ] },
};

// ════════════════════════════════════════════════════════════════
// SPEC CARD
// ════════════════════════════════════════════════════════════════
const WCSpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'6px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    {hex && <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}/>}
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);
const WCSpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1300, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'28px 32px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:12, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>WILDCARD · cockpit · fasit</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:26, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Chaos-meter er midtpunktet — brettet er rulebook</div>
    </div>
    <div style={{padding:'11px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a4a36', marginBottom:4}}>Uendret (gjenbruk)</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#2a4a36', lineHeight:1.5}}>Frame + scanlines, TopBar, ActionBar (UNDO · MISS · MENU) og den låste CRT-tavlen er urørt. WILDCARD legger KUN til <b>dim-states på segmenter</b> — brettet er alltid tappbart (dimmet treff = 0 poeng, men joker/cursed/bull utløses fortsatt).</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Nye elementer</div>
      <WCSpecRow zone="THIS TURN-direktiv — hva DENNE spilleren skal kaste (dominant)" val="NY · prioritert" hex={PURPLE}/>
      <WCSpecRow zone="CHAOS METER (0–10) — midtpunktet" val="heat-segmenter" hex={ORANGE}/>
      <WCSpecRow zone="Per-dart breakdown i aktiv-detalj" val="NY · mer data" hex={GREEN}/>
      <WCSpecRow zone="Standings — kompakt strip (👑leader / ▽last), nedprioritert" val="sekundær" hex={CYAN}/>
      <WCSpecRow zone="Modifier-badge + dimmet brett" val="live rulebook" hex={PURPLE}/>
      <WCSpecRow zone="THE WINDOW i scorecard-topp (3–9 · alle må score)" val="+100 prize" hex={PURPLE}/>
      <WCSpecRow zone="Bull-dialog (chaos ±1 / ±3)" val="strategisk spak" hex={YELLOW}/>
      <WCSpecRow zone="Joker reveal / instant events" val="signatur" hex={GREEN}/>
      <WCSpecRow zone="CUT! / REWIND / max-meter danger" val="moment-overlays" hex={RED}/>
    </div>
    <div style={{padding:'10px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Chaos-meter (fasit §3)</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:11.5, color:'#5a544a', lineHeight:1.5}}>Triple <b>+1</b> · true miss <b>−1</b> (dimmet treff er IKKE meter-miss) · joker <b>+2</b> · bull = spilleren velger <b>±1/±3</b>. Nivå driver event-frekvens + severity pool. Heat-farger: 1–2 cyan · 3–4 grønn · 5–6 gul · 7–8 oransje · 9–10 rød (danger-puls). Klemmes 0–10.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, fontWeight:800, color:'#2a251f', marginBottom:5, textTransform:'uppercase', letterSpacing:0.5}}>11 states</div>
      {[
        ['1 Default','Ingen modifier, meter idle. THIS TURN = OPEN THROW · SCORE MAX; kompakt standings under.'],
        ['2 Modifier announcement','Pre-turn overlay — «oh no»-øyeblikket, kun aktiv spiller.'],
        ['3 Active restriction','Badge + dimmet brett (ONLY EVENS → oddetall mørke).'],
        ['4 THE WINDOW','I scorecard-toppen (ikke egen banner): WINDOW 3–9 · ALL DARTS MUST SCORE.'],
        ['5 Bull choice','Dialog: ±1 (single) / ±3 (double bull), ignite vs calm.'],
        ['6 Joker reveal','Skjult tall detonerer → meter +2 + instant event (signatur).'],
        ['7 Instant event','Swap / steal / freeze-feedback (ROBIN HOOD vist).'],
        ['8 CUT!','Runden guillotineres — resten mister turen.'],
        ['9 REWIND','Rundens poeng slettes, restart fra første spiller (animasjon).'],
        ['10 Max meter','9–10: vedvarende danger-styling (rød vignette-puls).'],
        ['11 Winner','Høyest total etter siste runde.'],
      ].map(([t,b])=>(
        <div key={t} style={{display:'flex', gap:8, padding:'4px 0', borderBottom:'1px solid rgba(0,0,0,0.06)'}}>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:11.5, fontWeight:700, color:'#2a251f', flex:'0 0 168px'}}>{t}</div>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:11, lineHeight:1.35, color:'#5a544a'}}>{b}</div>
        </div>
      ))}
    </div>
    <div style={{marginTop:'auto', padding:'10px 14px', background:'#ede4f7', border:'1px solid rgba(177,92,255,0.35)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12, lineHeight:1.5, color:'#4a2a6a'}}>
        <b>Layout-prinsipp:</b> brettet holdes full størrelse (760, som X01/Gotcha) — det er hellig. Scorecard-en er bygget rundt én prioritet: <b>THIS TURN</b>-direktivet (hva DENNE spilleren skal kaste — restriksjon / WINDOW / open throw) er det dominante elementet, rett under aktiv-detaljen (avatar, per-dart, TURN, GAME + rank). De andre spillernes score er <b>nedprioritert</b> til en kompakt standings-strip (👑leader / ▽last). Rammen er litt høyere (820×1300, ~16:10 tablet) så alt får plass uten å krympe brettet. States 2 + 6–9 + winner er sentrerte dialog-popups. <b>Farge-roller:</b> lilla = chaos/modifier/direktiv · heat-gradient = meter · rød = fare/CUT!/max · gul = bull-valg + label · spillerfarge = total. Alle UI-strenger engelske (norsk-guard).
      </div>
    </div>
  </div>
);

// keyframes
if (typeof document !== 'undefined' && !document.getElementById('wildcard-kf')) {
  const st = document.createElement('style');
  st.id = 'wildcard-kf';
  st.textContent = `@keyframes wcPop { 0%{transform:scale(0.5) rotate(-5deg);opacity:0} 55%{transform:scale(1.12) rotate(3deg);opacity:1} 100%{transform:scale(1) rotate(0)} }
    @keyframes wcMaxPulse { 0%,100%{box-shadow:0 0 20px ${RED}55, inset 0 0 24px ${RED}33} 50%{box-shadow:0 0 36px ${RED}aa, inset 0 0 34px ${RED}55} }
    @keyframes wcSegPulse { 0%,100%{opacity:1} 50%{opacity:.5} }
    @keyframes wcDanger { 0%,100%{opacity:0.5} 50%{opacity:1} }
    @keyframes wcSpin { to{transform:rotate(360deg)} }
    @media (prefers-reduced-motion: reduce){ [style*="wc"]{animation:none!important} }`;
  document.head.appendChild(st);
}

// ── Canvas ───────────────────────────────────────────────────────
const WildcardCockpit = () => (
  <React.Fragment>
    <DCSection id="wc-cockpit" title="WILDCARD cockpit — chaos mode"
      subtitle="Points-race sabotert av kaos. Samme cockpit-chrome og den låste CRT-tavlen; WILDCARD legger KUN til dim-states på segmenter (brettet blir live rulebook). Det NYE: CHAOS METER (0–10) som alltid-synlig midtpunkt, modifier-announcement, dimmet restriksjons-brett, THE WINDOW, bull-dialog (chaos ±1/±3), joker reveal, instant events, CUT!, REWIND, max-meter danger og winner.">
      <DCArtboard id="wc-1" label="1 · Default (meter idle)" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.default}/></DCArtboard>
      <DCArtboard id="wc-2" label="2 · Modifier announcement" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.announce}/></DCArtboard>
      <DCArtboard id="wc-3" label="3 · Active restriction (dimmed board)" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.restrict}/></DCArtboard>
      <DCArtboard id="wc-4" label="4 · THE WINDOW" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.window}/></DCArtboard>
      <DCArtboard id="wc-5" label="5 · Bull choice (±1 / ±3)" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.bull}/></DCArtboard>
      <DCArtboard id="wc-6" label="6 · Joker reveal ← signatur" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.joker}/></DCArtboard>
      <DCArtboard id="wc-7" label="7 · Instant event (Robin Hood)" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.event}/></DCArtboard>
      <DCArtboard id="wc-8" label="8 · CUT!" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.cut}/></DCArtboard>
      <DCArtboard id="wc-9" label="9 · REWIND" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.rewind}/></DCArtboard>
      <DCArtboard id="wc-10" label="10 · Meter at max (danger)" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.maxmeter}/></DCArtboard>
      <DCArtboard id="wc-11" label="11 · Winner" width={WC_W} height={WC_H}><WCCockpit s={WC_STATES.winner}/></DCArtboard>
    </DCSection>

    <DCSection id="wc-spec" title="WILDCARD — fasit"
      subtitle="Chrome + brett er gjenbruk (kun dim-states nytt). Ny designinnsats: chaos-meter, alle overlays og de 11 statene.">
      <DCArtboard id="wc-spec-card" label="Spec · WILDCARD" width={680} height={1300}><WCSpecCard/></DCArtboard>
    </DCSection>
  </React.Fragment>
);
window.WildcardCockpit = WildcardCockpit;
