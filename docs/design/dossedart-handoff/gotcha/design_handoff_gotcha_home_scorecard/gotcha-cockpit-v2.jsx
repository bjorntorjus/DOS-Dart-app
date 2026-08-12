// DOSSEDART — Gotcha cockpit v2 · scorecard reworked for the KILL-HELP
// ───────────────────────────────────────────────────────────────
// Same arcade chrome, SAME locked CRT "BALANSERT" board (760), same
// MISS corners, same action bar (UNDO · MISS · MENU) — untouched.
// The ONLY thing redesigned is the scorecard: it is tightened so the
// two helpers below get their own clean, always-present bars:
//   • CHECKOUT helper — straight-out route toward the target (green)
//   • KILL helper — how to knock opponents out this dart (red / 💀)
// A slim climb-to-target bar replaces the old full-width LAST row and
// visualises every opponent as a tick — red when they are one dart away.

const GO_W = 820, GO_H = 1180;

const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', BG='#0a0014', SURFACE='#1a0030',
      PHOSPHOR='#D9D2C2';

// ════════════════════════════════════════════════════════════════
// LOCKED CRT "BALANSERT" BOARD — copied verbatim from gotcha.jsx.
// (Board / miss / sizes must stay identical to today.)
// ════════════════════════════════════════════════════════════════
const SECTORS = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5];
const DBULL=0.06, BULL=0.14, SINGLE_I=0.46, TRIPLE=0.64, SINGLE_O=0.86, DOUBLE=1.0, NUM=1.06;
const TAU=Math.PI*2, SEG=TAU/20;
const BOARD = { surround:'#05000e', base:'#05000e', darkSingle:'#190b32', lightSingle:'#3c2472',
  ringDark:'#e637a8', ringLight:'#2fc4dd', bullOuter:'#FFD200', bullStroke:'#FF7A00', bullInner:'#FF3050', num:'#fff' };

function wedge(cx,cy,rIn,rOut,a1,a2){
  const px=(r,a)=>cx+r*Math.cos(a), py=(r,a)=>cy+r*Math.sin(a);
  const large=(a2-a1)>Math.PI?1:0;
  return `M ${px(rIn,a1)} ${py(rIn,a1)} L ${px(rOut,a1)} ${py(rOut,a1)} A ${rOut} ${rOut} 0 ${large} 1 ${px(rOut,a2)} ${py(rOut,a2)} L ${px(rIn,a2)} ${py(rIn,a2)} A ${rIn} ${rIn} 0 ${large} 0 ${px(rIn,a1)} ${py(rIn,a1)} Z`;
}
function buildBoardSVG(size, o){
  const cx=size/2, cy=size/2, R=size*0.40;
  let s=`<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" style="display:block">`;
  s+=`<circle cx="${cx}" cy="${cy}" r="${R*1.14}" fill="${o.surround}"/>`;
  s+=`<circle cx="${cx}" cy="${cy}" r="${R*DOUBLE}" fill="${o.base}"/>`;
  for(let i=0;i<20;i++){
    const a1=-Math.PI/2+i*SEG-SEG/2, a2=a1+SEG;
    const isDark=(i%2===0);
    const single=isDark?o.darkSingle:o.lightSingle;
    const ring=isDark?o.ringDark:o.ringLight;
    s+=`<path d="${wedge(cx,cy,BULL*R,SINGLE_I*R,a1,a2)}" fill="${single}"/>`;
    s+=`<path d="${wedge(cx,cy,SINGLE_I*R,TRIPLE*R,a1,a2)}" fill="${ring}"/>`;
    s+=`<path d="${wedge(cx,cy,TRIPLE*R,SINGLE_O*R,a1,a2)}" fill="${single}"/>`;
    s+=`<path d="${wedge(cx,cy,SINGLE_O*R,DOUBLE*R,a1,a2)}" fill="${ring}"/>`;
  }
  s+=`<circle cx="${cx}" cy="${cy}" r="${BULL*R}" fill="${o.bullOuter}" stroke="${o.bullStroke}" stroke-width="2.5"/>`;
  s+=`<circle cx="${cx}" cy="${cy}" r="${DBULL*R}" fill="${o.bullInner}"/>`;
  const fs=size*0.04;
  SECTORS.forEach((n,i)=>{ const c=-Math.PI/2+i*SEG, x=cx+Math.cos(c)*NUM*R, y=cy+Math.sin(c)*NUM*R; s+=`<text x="${x}" y="${y+fs*0.36}" font-family="'Press Start 2P',monospace" font-size="${fs}" fill="${o.num}" text-anchor="middle">${n}</text>`; });
  return s+`</svg>`;
}
const CRTBoard = ({ size=300 }) => (
  <div style={{position:'relative', width:size, height:size}}>
    <div style={{filter:`drop-shadow(0 0 6px ${MAGENTA}44) drop-shadow(0 0 3px ${CYAN}33)`}}
         dangerouslySetInnerHTML={{__html: buildBoardSVG(size, BOARD)}}/>
    <div style={{position:'absolute', inset:0, pointerEvents:'none', background:'repeating-linear-gradient(0deg,rgba(0,0,0,0) 0px,rgba(0,0,0,0) 3px,rgba(0,0,0,0.26) 4px,rgba(0,0,0,0) 5px)'}}/>
    <div style={{position:'absolute', inset:0, pointerEvents:'none', borderRadius:'50%', background:'radial-gradient(ellipse 56% 42% at 50% 28%,rgba(255,255,255,0.10),transparent 60%)'}}/>
    <div style={{position:'absolute', inset:0, pointerEvents:'none', borderRadius:'50%', boxShadow:'inset 0 0 60px 10px rgba(0,0,0,0.7)'}}/>
  </div>
);

// ── shell chrome — identical to today ───────────────────────────
const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const Frame = ({ children }) => (
  <div style={{width:GO_W, height:GO_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {children}
  </div>
);
const TopBar = ({ target=301 }) => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>💀 GOTCHA · {target}</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>MÅL {target}</div>
  </div>
);
const ActionBar = () => (
  <div style={{position:'absolute', left:0, right:0, bottom:0, padding:'12px 16px 16px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:10, zIndex:6}}>
    <div style={{flex:1, padding:'14px', border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:2, padding:'14px', background:ORANGE, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:BG, letterSpacing:2, textAlign:'center', boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:1, padding:'14px', border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5, textAlign:'center'}}>⋯ MENU</div>
  </div>
);
const MissCorner = ({ pos }) => (
  <div style={{position:'absolute', ...pos, fontFamily:'"Press Start 2P", monospace', fontSize:9, color:MAGENTA, opacity:0.3, letterSpacing:1, pointerEvents:'none'}}>✗ MISS</div>
);

// ════════════════════════════════════════════════════════════════
// SCORECARD v2 — compact header + climb bar + the two helper strips
// ════════════════════════════════════════════════════════════════

// slim climb-to-target bar with every opponent placed as a tick.
// A tick turns red + skull when the active player is exactly one dart
// from landing on it (the kill helper made spatial).
const ClimbBar = ({ score, target, accent, opps }) => {
  const pct = (v)=> Math.max(0, Math.min(100, (v/target)*100));
  return (
    <div style={{marginTop:12}}>
      <div style={{position:'relative', height:14, background:'#05000e', border:`2px solid ${accent}44`, boxShadow:`inset 0 0 8px ${accent}22`}}>
        {/* your fill */}
        <div style={{position:'absolute', top:0, bottom:0, left:0, width:`${pct(score)}%`, background:`linear-gradient(90deg, ${accent}55, ${accent})`, boxShadow:`0 0 8px ${accent}aa`}}/>
        {/* your leading edge */}
        <div style={{position:'absolute', top:-3, bottom:-3, left:`calc(${pct(score)}% - 1px)`, width:3, background:'#fff', boxShadow:`0 0 6px #fff`}}/>
        {/* opponent ticks */}
        {opps.map((o,i)=>{
          const dead = o.total<=0;
          const kill = !!o.danger;
          const col = dead ? 'rgba(255,255,255,0.18)' : kill ? RED : PHOSPHOR;
          return (
            <div key={i} style={{position:'absolute', top:-9, bottom:-9, left:`calc(${pct(o.total)}% - 1px)`, width:2, background:col, boxShadow: kill?`0 0 6px ${RED}`:'none', animation: kill?'goSkullTick 1s infinite':'none'}}>
              <div style={{position:'absolute', top:-15, left:'50%', transform:'translateX(-50%)', fontFamily:'"VT323", monospace', fontSize:12, color:col, whiteSpace:'nowrap', lineHeight:1}}>{kill?'💀':o.name[0]}</div>
            </div>
          );
        })}
      </div>
      <div style={{display:'flex', justifyContent:'space-between', marginTop:5, fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.45)', letterSpacing:1}}>
        <span>0</span>
        <span style={{color:'rgba(255,255,255,0.6)'}}>CLIMB TO TARGET</span>
        <span style={{color:YELLOW}}>{target}</span>
      </div>
    </div>
  );
};

// generic helper bar shell — a labelled, always-present strip.
const HelperBar = ({ tag, tagColor, icon, active, children, emptyText }) => (
  <div style={{marginTop:10, display:'flex', alignItems:'stretch', border:`2px solid ${active?tagColor:'rgba(255,255,255,0.14)'}`,
               background: active?`${tagColor}12`:'rgba(255,255,255,0.02)',
               boxShadow: active?`0 0 14px ${tagColor}40`:'none', opacity: active?1:0.5, minHeight:46}}>
    <div style={{display:'flex', alignItems:'center', gap:7, padding:'0 12px', background: active?`${tagColor}22`:'transparent', borderRight:`2px solid ${active?tagColor:'rgba(255,255,255,0.14)'}`}}>
      <span style={{fontSize:15, lineHeight:1, filter: active?'none':'grayscale(1)'}}>{icon}</span>
      <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color: active?tagColor:'rgba(255,255,255,0.4)', letterSpacing:1, textShadow: active?`0 0 6px ${tagColor}`:'none'}}>{tag}</span>
    </div>
    <div style={{flex:1, display:'flex', alignItems:'center', padding:'0 14px', minWidth:0}}>
      {active ? children : <span style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.4)', letterSpacing:1}}>{emptyText}</span>}
    </div>
  </div>
);

const CheckoutHelper = ({ win }) => (
  <HelperBar tag="CHECKOUT" tagColor={GREEN} icon="🎯" active={!!win} emptyText="INGEN RUTE · > 3 DART">
    {win && (
      <React.Fragment>
        <div style={{flex:1, fontFamily:'"Press Start 2P", monospace', fontSize:13, color:'#fff', letterSpacing:1, textShadow:`0 0 6px ${GREEN}66`}}>{win.route}</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:GREEN, letterSpacing:1, textShadow:`0 0 6px ${GREEN}`}}>WIN ▶</div>
      </React.Fragment>
    )}
  </HelperBar>
);

const KillHelper = ({ kills }) => (
  <HelperBar tag="KILL" tagColor={RED} icon="💀" active={!!(kills && kills.length)} emptyText="INGEN INNEN 1 DART">
    {kills && kills.length>0 && (
      <div style={{flex:1, display:'flex', flexWrap:'wrap', gap:'4px 8px', alignItems:'center'}}>
        {kills.map((k,i)=>(
          <span key={i} style={{display:'inline-flex', alignItems:'center', gap:6, padding:'3px 8px', background:`${RED}22`, border:`1px solid ${RED}88`}}>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'#ff8fa6', letterSpacing:.5}}>{k.dart}</span>
            <span style={{fontFamily:'"VT323", monospace', fontSize:16, color:'#fff', letterSpacing:1}}>→ {k.name.toUpperCase()}</span>
          </span>
        ))}
      </div>
    )}
  </HelperBar>
);

const ScoreCard = ({ p, target, win, kills, opps }) => {
  const c = p.accent || CYAN;
  const toGo = target - p.total;
  return (
    <div style={{margin:'16px 14px 0', padding:'13px 16px', position:'relative',
                 border:`3px solid ${c}`,
                 background:`linear-gradient(180deg, ${c}1a 0%, ${c}05 100%)`,
                 boxShadow:`0 0 16px ${c}40`, zIndex:6}}>
      <div style={{position:'absolute', top:-9, left:16, padding:'3px 9px', background:c, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:9, letterSpacing:1.5, boxShadow:`0 0 8px ${c}aa`}}>▶ NOW THROWING</div>

      {/* compact header — LAST folded inline, no full-width LAST row */}
      <div style={{display:'flex', alignItems:'center', gap:13, marginTop:3}}>
        <div style={{width:52, height:52, background:BG, border:`3px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:14, color:c, textShadow:`0 0 8px ${c}aa`, flexShrink:0, boxShadow:`0 0 12px ${c}55`}}>{p.handle}</div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:17, color:'#fff', letterSpacing:2, lineHeight:1}}>{p.name.toUpperCase()}</div>
          <div style={{display:'flex', alignItems:'center', gap:9, marginTop:8}}>
            <div style={{display:'flex', gap:5}}>
              {[0,1,2].map(i=>(
                <div key={i} style={{width:9, height:9, background:i<p.dartIdx?c:'transparent', border:`2px solid ${c}`, boxShadow:i<p.dartIdx?`0 0 6px ${c}aa`:'none'}}></div>
              ))}
            </div>
            <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>DART {p.dartIdx}/3</span>
            <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.28)'}}>·</span>
            <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>LAST</span>
            <span style={{fontFamily:'"VT323", monospace', fontSize:16, color:YELLOW, letterSpacing:.5}}>{p.last || '—'}</span>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:YELLOW}}>={p.lastSum!=null?p.lastSum:0}</span>
          </div>
        </div>
        <div style={{textAlign:'right', flexShrink:0}}>
          <div style={{display:'flex', alignItems:'baseline', gap:8, justifyContent:'flex-end'}}>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.55)', letterSpacing:1}}>SCORE</span>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:46, color:c, lineHeight:1, textShadow:`0 0 16px ${c}aa`, letterSpacing:-2}}>{p.total}</span>
          </div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:YELLOW, letterSpacing:1, marginTop:5}}>TO GO · <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11}}>{toGo}</span></div>
        </div>
      </div>

      <ClimbBar score={p.total} target={target} accent={c} opps={opps}/>

      {/* the two helpers — always present so the layout never jumps
          into the board; dim when nothing applies */}
      <CheckoutHelper win={win}/>
      <KillHelper kills={kills}/>
    </div>
  );
};

// ════════════════════════════════════════════════════════════════
// COCKPIT — board / miss / action bar all unchanged (760 @ top330)
// ════════════════════════════════════════════════════════════════
const Cockpit = ({ s }) => (
  <Frame>
    <TopBar target={s.target}/>
    <ScoreCard p={s.active} target={s.target} win={s.win} kills={s.kills} opps={s.opps}/>
    <div style={{position:'absolute', left:0, right:0, top:330, bottom:66, display:'flex', alignItems:'center', justifyContent:'center', zIndex:3}}>
      <div style={{position:'absolute', width:740, height:740, borderRadius:'50%', boxShadow:`0 0 70px ${MAGENTA}3a`, pointerEvents:'none'}}></div>
      <MissCorner pos={{top:6, left:18}}/>
      <MissCorner pos={{top:6, right:18}}/>
      <MissCorner pos={{bottom:6, left:18}}/>
      <MissCorner pos={{bottom:6, right:18}}/>
      <CRTBoard size={760}/>
    </div>
    <ActionBar/>
  </Frame>
);

// ── scenarios (target 301) ──────────────────────────────────────
const P = (name, handle, total, dartIdx=1, last='—', lastSum=0, accent=CYAN) => ({ name, handle, total, dartIdx, last, lastSum, accent });
const O = (name, total, opts={}) => ({ name, total, ...opts });

const STATES = {
  default: { target:301,
    active:P('Jonas','JON',60,1,'S20·S20·S20',60),
    opps:[O('Kari',78), O('Per',45), O('Mia',0)],
  },
  checkout: { target:301,
    active:P('Jonas','JON',211,1,'T20·S20·S11',91),
    win:{ route:'T20 › D15' },
    opps:[O('Kari',150), O('Per',178), O('Mia',96)],
  },
  kill: { target:301,
    active:P('Jonas','JON',132,1,'T17·S20·S13',84),
    kills:[{dart:'S17', name:'Kari'}, {dart:'D20', name:'Per'}],
    opps:[O('Kari',149,{danger:true}), O('Per',172,{danger:true}), O('Mia',0)],
  },
  both: { target:301,
    active:P('Jonas','JON',261,2,'T19·S20·D14',105),
    win:{ route:'D20' },
    kills:[{dart:'S12', name:'Kari'}],
    opps:[O('Kari',273,{danger:true}), O('Per',210), O('Mia',144)],
  },
};

// ════════════════════════════════════════════════════════════════
// SPEC CARD — what changed vs today
// ════════════════════════════════════════════════════════════════
const SpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    {hex && <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}/>}
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);
const SpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:15, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Gotcha cockpit · v2 · kill-help</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:26, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Scorecard omgjort — plass til begge hjelperne</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Uendret</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Brettet (låst CRT «BALANSERT», <b style={{color:'#2a251f'}}>760px @ top 330</b>), MISS-hjørnene, glow-ringen og action-baren (<b style={{color:'#2a251f'}}>UNDO · MISS · MENU</b>) er <b style={{color:'#2a251f'}}>helt like som i dag</b>. All ny plass er hentet fra selve scorecardet.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Hva som er endret i scorecardet</div>
      {[
        ['Kompakt header','Avatar, navn, dart-prikker, DART x/3 og LAST-kastet ligger nå på én linje. Den gamle brede LAST-raden er fjernet → ~44px spart.'],
        ['Climb-to-target bar','En tynn stolpe 0→mål erstatter LAST-raden. Din posisjon = hvit kant; hver motstander = en tick. Ticken blir rød med 💀 når du er nøyaktig 1 dart unna å lande på den.'],
        ['To faste hjelper-barer','CHECKOUT (grønn) og KILL (rød) har hver sin merkede bar, alltid til stede. Tomme states er dimmet — layouten hopper aldri ned i brettet.'],
      ].map(([t,b])=>(
        <div key={t} style={{padding:'8px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, fontWeight:700, color:'#2a251f'}}>{t}</div>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:11.5, lineHeight:1.45, color:'#5a544a', marginTop:2}}>{b}</div>
        </div>
      ))}
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>De to hjelperne</div>
      <SpecRow zone="CHECKOUT — straight-out rute mot mål" val="≤3 dart · 🎯 grønn" hex={GREEN}/>
      <SpecRow zone="KILL — slå ut motspiller (1 dart)" val="dart → navn · 💀 rød" hex={RED}/>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:11.5, color:'#5a544a', lineHeight:1.5, marginTop:8}}>Begge kan vises samtidig (state 4). CHECKOUT bruker den nye <b style={{color:'#2a251f'}}>straight_out_checkout</b>-utilen; KILL viser <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>diff = motstander − meg</code> som enkleste dart-notasjon per motstander innen 1 dart.</div>
    </div>
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#2a4a36'}}>
        <b>Farge-roller (uendret system):</b> aktiv = spillerens farge (cyan), gul = LAST/score-label + mål, grønn = checkout, rød/💀 = kill. Bust · GOTCHA-event · winner gjenbruker appens egne rutiner — ikke designet her.
      </div>
    </div>
  </div>
);

// keyframes for the pulsing kill ticks
if (typeof document !== 'undefined' && !document.getElementById('gotcha-v2-kf')) {
  const st = document.createElement('style');
  st.id = 'gotcha-v2-kf';
  st.textContent = `@keyframes goSkullTick { 0%,100%{opacity:1} 50%{opacity:.4} }
    @media (prefers-reduced-motion: reduce){ [style*="goSkullTick"]{animation:none!important} }`;
  document.head.appendChild(st);
}

// ── Canvas ──────────────────────────────────────────────────────
const GotchaCockpitV2 = () => (
  <React.Fragment>
    <DCSection id="gv2-cockpit" title="Gotcha cockpit v2 — scorecard omgjort for kill-help"
      subtitle="Samme chrome og SAMME brett/MISS/action-bar som i dag. Scorecardet er strammet: kompakt header med LAST inline, en tynn climb-to-target-bar der hver motstander er en tick (rød 💀 når du er 1 dart unna), og to faste hjelper-barer — CHECKOUT (grønn) og KILL (rød). Barene er alltid til stede (dimmet når tomme) så layouten aldri hopper ned i brettet.">
      <DCArtboard id="gv2-1" label="1 · Default (ingen hjelp)" width={GO_W} height={GO_H}><Cockpit s={STATES.default}/></DCArtboard>
      <DCArtboard id="gv2-2" label="2 · CHECKOUT helper" width={GO_W} height={GO_H}><Cockpit s={STATES.checkout}/></DCArtboard>
      <DCArtboard id="gv2-3" label="3 · KILL helper ← det nye" width={GO_W} height={GO_H}><Cockpit s={STATES.kill}/></DCArtboard>
      <DCArtboard id="gv2-4" label="4 · CHECKOUT + KILL sammen" width={GO_W} height={GO_H}><Cockpit s={STATES.both}/></DCArtboard>
    </DCSection>

    <DCSection id="gv2-spec" title="Hva som er endret"
      subtitle="Brett, MISS og action-bar er urørt. All plass er hentet fra scorecardet.">
      <DCArtboard id="gv2-spec-card" label="Spec · endringer" width={680} height={1180}><SpecCard/></DCArtboard>
    </DCSection>
  </React.Fragment>
);
window.GotchaCockpitV2 = GotchaCockpitV2;
