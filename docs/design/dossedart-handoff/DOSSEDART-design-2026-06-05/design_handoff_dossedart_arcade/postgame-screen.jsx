// DOSSEDART — Post-game screen (3 directions)
// Shown after any match. Data per player: placement, name, avatar, mode-specific
// stat line, ELO delta. Actions: rematch / continue (if eligible) / home / undo.
// Settings + Statistics entry points live up here too (to be designed later).
//   A · CHAMPION   — winner spotlight + final standings list (any count)  ← REC
//   B · LEADERBOARD— retro HIGH-SCORE table (rank·player·stat·ΔELO)
//   C · PODIUM     — 1-2-3 pedestal podium + ELO row
//
// Locked: active/you=cyan, full names, gold=1st, scores readable. Same chrome.

const PG_W = 820, PG_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#1a0030';
const PHOSPHOR= '#D9D2C2';
const SILVER  = '#c9d2da';
const BRONZE  = '#d08a4a';

const MODE = 'X01 · 501';
// "you" = Jonas (the player on this device) — highlighted cyan in lists.
const RESULTS = [
  { place:1, name:'Jonas',   you:true, headline:['SNITT','62.4'], stat:'Best 140 · 24 piler · ut D20', elo:+12.3 },
  { place:2, name:'Andreas', headline:['SNITT','55.1'], stat:'Best 121 · 27 piler', elo:+3.1 },
  { place:3, name:'Mia',     headline:['SNITT','41.8'], stat:'Best 100 · 33 piler · ikke ut', elo:-8.4 },
];
const WINNER = RESULTS[0];
const placeColor = (p) => p===1?YELLOW:p===2?SILVER:p===3?BRONZE:'rgba(217,210,194,0.6)';

if (typeof document !== 'undefined' && !document.getElementById('pg-kf')) {
  const s = document.createElement('style');
  s.id = 'pg-kf';
  s.textContent = `
    @keyframes pgShine { 0%,100%{opacity:.8} 50%{opacity:.35} }
    @keyframes pgStar { 0%,100%{opacity:.4; transform:translateY(0)} 50%{opacity:1; transform:translateY(-3px)} }
    @media (prefers-reduced-motion: reduce){ .pg-shine,.pg-star{animation:none!important} }`;
  document.head.appendChild(s);
}

// ── bits ────────────────────────────────────────────────────────
const Avatar = ({ size=48, color=PHOSPHOR }) => (
  <div style={{width:size, height:size, borderRadius:'50%', background:'#1a0030', border:`2px solid ${color}`, display:'flex', alignItems:'flex-end', justifyContent:'center', flexShrink:0, overflow:'hidden', boxShadow:`0 0 12px ${color}44`}}>
    <svg width={size*0.8} height={size*0.8} viewBox="0 0 24 24" style={{marginBottom:-1}}>
      <circle cx="12" cy="9" r="4.4" fill={color} opacity="0.9"/>
      <path d="M3.5 22c0-5 3.8-8 8.5-8s8.5 3 8.5 8z" fill={color} opacity="0.9"/>
    </svg>
  </div>
);
const Crown = ({ size=40 }) => (
  <svg width={size} height={size*0.72} viewBox="0 0 28 20" style={{display:'block', filter:`drop-shadow(0 0 6px ${YELLOW}aa)`}}>
    <path d="M2 18 L4.5 5 L9.5 12 L14 2.5 L18.5 12 L23.5 5 L26 18 Z" fill={YELLOW} stroke="#a87b00" strokeWidth="1"/>
    <rect x="2" y="16.5" width="24" height="3.5" fill={YELLOW} stroke="#a87b00" strokeWidth="0.5"/>
  </svg>
);
const Elo = ({ d, big }) => {
  const up = d>0, col = up?GREEN:d<0?RED:'rgba(255,255,255,0.5)';
  return (
    <div style={{display:'flex', flexDirection:'column', alignItems:'flex-end'}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:big?13:12, color:'rgba(255,255,255,0.4)', letterSpacing:2}}>ELO</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:big?14:12, color:col, textShadow:`0 0 6px ${col}88`, marginTop:2}}>{up?'▲':d<0?'▼':'='} {d>0?'+':''}{d.toFixed(1)}</div>
    </div>
  );
};

// ── Shared chrome ───────────────────────────────────────────────
const Frame = ({ children }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:PG_W, height:PG_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
      {children}
    </div>
  );
};
// header: mode · GAME OVER · settings/stats entry points (to be designed later)
const IconBtn = ({ label }) => (
  <div style={{padding:'6px 9px', border:`2px solid ${CYAN}66`, display:'flex', alignItems:'center', gap:5, fontFamily:'"Press Start 2P", monospace', fontSize:8, color:CYAN, letterSpacing:1}}>{label}</div>
);
const HeaderBar = () => (
  <div style={{padding:'12px 16px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:10, position:'relative', zIndex:6}}>
    <div style={{flex:1, fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>{MODE}</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:YELLOW, letterSpacing:2, textShadow:`0 0 8px ${YELLOW}aa`}}>GAME OVER</div>
    <div style={{flex:1, display:'flex', justifyContent:'flex-end', gap:7}}>
      <IconBtn label="⚙ INNST."/>
      <IconBtn label="▤ STATS"/>
    </div>
  </div>
);
const ActionBar = ({ canContinue }) => (
  <div style={{padding:'12px 16px 16px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:10, position:'relative', zIndex:6}}>
    <div style={{flex:1, padding:'15px 8px', border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'#fff', letterSpacing:1, textAlign:'center'}}>↶ ANGRE</div>
    {canContinue && <div style={{flex:1.4, padding:'15px 8px', border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:CYAN, letterSpacing:1, textAlign:'center'}}>▶ FORTSETT</div>}
    <div style={{flex:2, padding:'15px 8px', background:CYAN, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:BG, letterSpacing:1.5, textAlign:'center', boxShadow:`0 0 16px ${CYAN}8c`}}>↻ OMKAMP</div>
    <div style={{flex:1.4, padding:'15px 8px', border:`2px solid ${ORANGE}`, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:ORANGE, letterSpacing:1, textAlign:'center'}}>⌂ HJEM</div>
  </div>
);

// ════════════════════════════════════════════════════════════════
// A · CHAMPION  (recommended)
// ════════════════════════════════════════════════════════════════
const StandRow = ({ r }) => {
  const c = placeColor(r.place);
  return (
    <div style={{display:'flex', alignItems:'center', gap:13, padding:'12px 14px', border:`2px solid ${r.place===1?YELLOW:`${MAGENTA}30`}`, background:r.place===1?`${YELLOW}0e`:r.you?`${CYAN}0c`:'rgba(255,255,255,0.02)'}}>
      <div style={{width:34, height:34, borderRadius:'50%', border:`2px solid ${c}`, background:`${c}1e`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, textShadow:`0 0 6px ${c}88`, flexShrink:0}}>{r.place}</div>
      <Avatar size={40} color={r.you?CYAN:c}/>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:7}}>
          <span style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:16, color:r.you?CYAN:'#fff', whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{r.name}</span>
          {r.you && <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:7, color:CYAN, letterSpacing:1}}>DEG</span>}
        </div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.55)', letterSpacing:1, marginTop:3}}>{r.headline[0]} {r.headline[1]} · {r.stat}</div>
      </div>
      <Elo d={r.elo}/>
    </div>
  );
};
const CockpitA = () => (
  <Frame>
    <HeaderBar/>
    {/* winner spotlight */}
    <div style={{position:'relative', padding:'22px 16px 20px', display:'flex', flexDirection:'column', alignItems:'center', gap:8, background:`radial-gradient(ellipse at 50% 0%, ${YELLOW}1c 0%, transparent 70%)`, borderBottom:`1px solid ${MAGENTA}33`}}>
      {/* sparkle row */}
      <div style={{display:'flex', gap:24, position:'absolute', top:14, left:0, right:0, justifyContent:'center'}}>
        {[0,1,2,3,4].map(i=><span key={i} className="pg-star" style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:YELLOW, opacity:0.6, animation:`pgStar ${1+i*0.2}s ease-in-out infinite`}}>✦</span>)}
      </div>
      <Crown size={44}/>
      <Avatar size={92} color={YELLOW}/>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:24, color:'#fff', letterSpacing:1, textShadow:`0 0 14px ${YELLOW}66`, marginTop:2}}>{WINNER.name.toUpperCase()}</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:YELLOW, letterSpacing:3, textShadow:`0 0 10px ${YELLOW}aa`}}>★ VINNER ★</div>
      <div style={{display:'flex', alignItems:'center', gap:12, marginTop:8}}>
        <div style={{padding:'8px 14px', border:`2px solid ${YELLOW}`, background:`${YELLOW}10`, textAlign:'center'}}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>{WINNER.headline[0]}</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:20, color:YELLOW, textShadow:`0 0 10px ${YELLOW}aa`, marginTop:3}}>{WINNER.headline[1]}</div>
        </div>
        <div style={{padding:'8px 14px', border:`2px solid ${GREEN}`, background:`${GREEN}10`, textAlign:'center'}}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>ELO</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:20, color:GREEN, textShadow:`0 0 10px ${GREEN}aa`, marginTop:3}}>+{WINNER.elo.toFixed(1)}</div>
        </div>
      </div>
    </div>
    {/* final standings */}
    <div style={{flex:1, padding:'14px 16px 0', display:'flex', flexDirection:'column', gap:10, minHeight:0, overflow:'hidden'}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>SLUTTSTILLING</div>
      {RESULTS.map(r => <StandRow key={r.name} r={r}/>)}
    </div>
    <ActionBar canContinue={false}/>
  </Frame>
);

// ════════════════════════════════════════════════════════════════
// B · LEADERBOARD  (retro high-score table)
// ════════════════════════════════════════════════════════════════
const CockpitB = () => (
  <Frame>
    <HeaderBar/>
    <div style={{flex:1, padding:'24px 18px 0', display:'flex', flexDirection:'column', minHeight:0}}>
      <div style={{textAlign:'center', marginBottom:20}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:26, color:YELLOW, letterSpacing:3, textShadow:`0 0 16px ${YELLOW}aa`}}>HIGH SCORE</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.5)', letterSpacing:3, marginTop:6}}>SLUTTSTILLING · {MODE}</div>
      </div>
      {/* table head */}
      <div style={{display:'grid', gridTemplateColumns:'52px 1fr 110px 92px', gap:10, padding:'0 12px 10px', borderBottom:`2px solid ${MAGENTA}55`, fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>
        <div>RANK</div><div>SPILLER</div><div style={{textAlign:'right'}}>SNITT</div><div style={{textAlign:'right'}}>ELO</div>
      </div>
      {RESULTS.map(r=>{
        const c = placeColor(r.place);
        return (
          <div key={r.name} className={r.place===1?'pg-shine':''} style={{display:'grid', gridTemplateColumns:'52px 1fr 110px 92px', gap:10, alignItems:'center', padding:'16px 12px', borderBottom:`1px solid ${MAGENTA}22`, background:r.place===1?`${YELLOW}10`:r.you?`${CYAN}08`:'transparent', boxShadow:r.place===1?`inset 0 0 22px ${YELLOW}1c`:'none'}}>
            <div style={{display:'flex', alignItems:'center', gap:6}}>
              {r.place===1 && <Crown size={22}/>}
              <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:c, textShadow:`0 0 6px ${c}88`}}>{r.place}</span>
            </div>
            <div style={{display:'flex', alignItems:'center', gap:10, minWidth:0}}>
              <Avatar size={34} color={r.you?CYAN:c}/>
              <span style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:16, color:r.you?CYAN:'#fff', whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{r.name}{r.you?' ·DEG':''}</span>
            </div>
            <div style={{textAlign:'right', fontFamily:'"Press Start 2P", monospace', fontSize:16, color:r.place===1?YELLOW:'#fff', textShadow:r.place===1?`0 0 8px ${YELLOW}88`:'none'}}>{r.headline[1]}</div>
            <div style={{display:'flex', justifyContent:'flex-end'}}><Elo d={r.elo}/></div>
          </div>
        );
      })}
      <div style={{marginTop:14, fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.45)', letterSpacing:1, textAlign:'center'}}>★ {WINNER.name} vant med snitt {WINNER.headline[1]} ★</div>
    </div>
    <ActionBar canContinue={false}/>
  </Frame>
);

// ════════════════════════════════════════════════════════════════
// C · PODIUM  (1-2-3 pedestal)
// ════════════════════════════════════════════════════════════════
const Pedestal = ({ r, h }) => {
  const c = placeColor(r.place);
  return (
    <div style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'flex-end', gap:0}}>
      <div style={{display:'flex', flexDirection:'column', alignItems:'center', gap:6, marginBottom:10}}>
        {r.place===1 && <Crown size={36}/>}
        <Avatar size={r.place===1?78:60} color={c}/>
        <div style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:r.place===1?17:15, color:r.you?CYAN:'#fff', textAlign:'center', whiteSpace:'nowrap'}}>{r.name}{r.you?' ·DEG':''}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.55)', letterSpacing:1}}>{r.headline[0]} <b style={{color:c, fontFamily:'"Press Start 2P", monospace', fontSize:11}}>{r.headline[1]}</b></div>
        <Elo d={r.elo}/>
      </div>
      <div style={{width:'88%', height:h, background:`linear-gradient(180deg, ${c}2e 0%, ${c}10 100%)`, border:`2px solid ${c}`, borderBottom:'none', display:'flex', alignItems:'flex-start', justifyContent:'center', paddingTop:14, boxShadow:`0 0 22px ${c}33`}}>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:34, color:c, textShadow:`0 0 12px ${c}aa`}}>{r.place}</span>
      </div>
    </div>
  );
};
const CockpitC = () => {
  const first = RESULTS.find(r=>r.place===1);
  const second = RESULTS.find(r=>r.place===2);
  const third = RESULTS.find(r=>r.place===3);
  return (
    <Frame>
      <HeaderBar/>
      <div style={{textAlign:'center', padding:'18px 0 4px'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:YELLOW, letterSpacing:3, textShadow:`0 0 10px ${YELLOW}aa`}}>SLUTTSTILLING</div>
      </div>
      <div style={{flex:1, display:'flex', alignItems:'flex-end', justifyContent:'center', gap:8, padding:'0 18px', minHeight:0}}>
        {second && <Pedestal r={second} h={210}/>}
        {first && <Pedestal r={first} h={300}/>}
        {third && <Pedestal r={third} h={150}/>}
      </div>
      <ActionBar canContinue={false}/>
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
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Post-game · champion</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Hvorfor A</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Vinner-spotlight feirer, og <b style={{color:'#2a251f'}}>sluttstillingen</b> under gir full info: plassering, snitt/mode-stat, ELO-endring — uansett antall spillere. C (podium) er gøy for 2–4 men kludrete for 1 eller mange; B (high-score) er mest retro men tettere. A skalerer best og bærer stat-linja per modus.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Farger (per rolle)</div>
      <SpecRow zone="1. plass / vinner / krone" val="#FFD200" hex={YELLOW}/>
      <SpecRow zone="2. plass (sølv)" val="#C9D2DA" hex={SILVER}/>
      <SpecRow zone="3. plass (bronse)" val="#D08A4A" hex={BRONZE}/>
      <SpecRow zone="Deg (denne enheten)" val="#00E5FF" hex={CYAN}/>
      <SpecRow zone="ELO opp / ned" val="#3DFF8E / #FF3050" hex={GREEN}/>
      <SpecRow zone="OMKAMP (primær)" val="#00E5FF" hex={CYAN}/>
      <SpecRow zone="HJEM-accent · ramme" val="#FF7A00 · #FF00AA" hex={ORANGE}/>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Mode-stat-linje (GameResult.stats)</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12, color:'#5a544a', lineHeight:1.55}}><b style={{color:'#2a251f'}}>X01:</b> snitt · best · piler · checkout. <b style={{color:'#2a251f'}}>Cricket:</b> poeng · lukket. <b style={{color:'#2a251f'}}>Around the Clock:</b> nådd · piler. <b style={{color:'#2a251f'}}>Killer:</b> liv igjen. <b style={{color:'#2a251f'}}>Splitscore:</b> total · halveringer. <b style={{color:'#2a251f'}}>Shanghai:</b> total · (Shanghai!-flagg ved direkte seier). Headline = snitt/score per modus; resten i stat-linja.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Arcade-skjerm','Erstatt classic Scaffold/Card-liste med DOSSEDART-chrome: ArcadeFrame (CRT), header (GAME OVER + entry-points), vinner-spotlight, sluttstilling, action-bar.'],
        ['2','Skalerer på antall','Spotlight = winner (results[0] etter placement). Sluttstilling = ListView over alle results. 1 spiller → kun spotlight + «ny rekord?». Likhet/uavgjort → vis delt 1. plass.'],
        ['3','Handlinger','OMKAMP (pop «rematch»), FORTSETT (kun når canContinue), HJEM (pop «home»), ANGRE (pop «undo»). Samme retur-kontrakt som dagens PostGameScreen.'],
        ['4','Innstillinger + statistikk','Entry-points i headeren (⚙ INNST. · ▤ STATS) — egne skjermer designes senere. Plasshold nå så navigasjonen finnes.'],
        ['5','Én farge-logikk','Gull/sølv/bronse for pall, cyan = deg, grønn/rød = ELO. Ingen per-spiller-rainbow. Fulle navn, ikke forkortelser.'],
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
        <b>Konsistens:</b> samme chrome + farge-prinsipp som de seks cockpit-ene. Innstillinger + statistikk er entry-points her, men egne skjermer kommer senere (som avtalt).
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const PostgameScreen = () => (
  <DCSection
    id="postgame-directions"
    title="Post-game — skjerm (3 retninger)"
    subtitle="Etter en kamp: vinner, sluttstilling, mode-stat per spiller, ELO-endring, og handlinger (omkamp / fortsett / hjem / angre). Innstillinger + statistikk har entry-points i headeren (egne skjermer designes senere). Vist med et X01-resultat (mest stat-rikt). Anbefalt: A · champion — vinner-spotlight + sluttstilling, skalerer på antall spillere.">
    <DCArtboard id="pg-a" label="A · Champion (spotlight + stilling)  ← anbefalt" width={PG_W} height={PG_H}><CockpitA/></DCArtboard>
    <DCArtboard id="pg-b" label="B · Leaderboard (high-score)" width={PG_W} height={PG_H}><CockpitB/></DCArtboard>
    <DCArtboard id="pg-c" label="C · Podium (1-2-3 pall)" width={PG_W} height={PG_H}><CockpitC/></DCArtboard>
    <DCArtboard id="pg-spec" label="Implementasjon · spec + tokens (retning A)" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.PostgameScreen = PostgameScreen;

// ── Locked final — direction A (champion) ───────────────────────
const PostgameScreenFinal = () => (
  <DCSection
    id="postgame-final"
    title="Post-game — final (champion)"
    subtitle="Valgt retning A. Vinner-spotlight (krone, avatar, ★ VINNER ★, snitt + ELO) over en full sluttstilling med plassering, mode-stat og ELO-endring per spiller — skalerer på antall spillere. Innstillinger + statistikk har entry-points i headeren (egne skjermer kommer). Handlinger: angre / omkamp / hjem (+ fortsett når mulig).">
    <DCArtboard id="pgf-screen" label="Skjerm · post-game · champion" width={PG_W} height={PG_H}><CockpitA/></DCArtboard>
    <DCArtboard id="pgf-spec" label="Implementasjon · spec + tokens" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.PostgameScreenFinal = PostgameScreenFinal;
