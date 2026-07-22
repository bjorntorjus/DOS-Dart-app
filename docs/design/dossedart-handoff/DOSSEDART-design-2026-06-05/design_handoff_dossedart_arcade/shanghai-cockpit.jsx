// DOSSEDART — Shanghai cockpit (3 directions) · final gamemode
// Rounds 1 → N (7/9/20). Every player shoots the SAME number = the round number.
// Score = single/double/triple × the number, cumulative. Hit a SINGLE + DOUBLE +
// TRIPLE of the number IN ONE TURN → instant win ("Shanghai!"). Else highest
// total after the last round wins. Input is just S/D/T of the current number —
// no full board needed — so the three input cells double as the SHANGHAI CHASE
// tracker (light up as you hit them this turn).
//   A · CHASE     — the S/D/T chase cells are hero + input; banner + ladder  ← REC
//   B · JOURNEY   — the 1→N round journey is the hero; chase below
//   C · SCORECARD — round×player history grid; chase compact
//
// Carries the two latest decisions: player scores at the TOP, clean cells
// (no "=N P" math). Locked: active=cyan, others=phosphor, full names.

const SH_W = 820, SH_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#1a0030';
const PHOSPHOR= '#D9D2C2';

const ROUND = 3, ROUNDS_END = 7, TARGET = ROUND; // round 3, target = 3
// active player's hits THIS turn — single + double done, one triple from Shanghai
const TURN_HITS = { single:true, double:true, triple:false };

const PLAYERS = [
  { name:'Andreas', handle:'AND', total:21, cells:[6,15,null,null,null,null,null] },
  { name:'Jonas',   handle:'JON', active:true, dartIdx:2, total:16, turnPts:9, cells:[4,12,'LIVE',null,null,null,null] },
  { name:'Mia',     handle:'MIA', total:11, cells:[3,8,null,null,null,null,null] },
];
const ACTIVE = PLAYERS.find(p => p.active);
const LEADER = PLAYERS.reduce((a,b)=>b.total>a.total?b:a);
const GOT = Object.values(TURN_HITS).filter(Boolean).length;
const ONE_AWAY = GOT === 2;

if (typeof document !== 'undefined' && !document.getElementById('sh-kf')) {
  const s = document.createElement('style');
  s.id = 'sh-kf';
  s.textContent = `
    @keyframes shPulse { 0%,100%{opacity:1} 50%{opacity:.45} }
    @keyframes shGlow { 0%,100%{box-shadow:0 0 12px ${YELLOW}66; border-color:${YELLOW}} 50%{box-shadow:0 0 26px ${YELLOW}cc; border-color:#fff0a0} }
    @media (prefers-reduced-motion: reduce){ .sh-pulse,.sh-glow{animation:none!important} }`;
  document.head.appendChild(s);
}

// ── Shared chrome ───────────────────────────────────────────────
const Frame = ({ children }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:SH_W, height:SH_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
      {children}
    </div>
  );
};
const TopBar = () => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>SHANGHAI · 1→{ROUNDS_END}</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>RND {ROUND}/{ROUNDS_END}</div>
  </div>
);
const DartDots = ({ idx=2, color=CYAN, size=11 }) => (
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

// Active strip — identity + dart dots + this round/target + TOTAL
const ActiveStrip = () => {
  const p = ACTIVE, c = CYAN;
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
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.65)', letterSpacing:2}}>MÅL · <span style={{color:YELLOW, fontFamily:'"Press Start 2P", monospace', fontSize:11}}>{TARGET}</span> · +{p.turnPts} denne turen</div>
        </div>
      </div>
      <div style={{textAlign:'right'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>TOTAL</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:36, color:c, lineHeight:1, textShadow:`0 0 16px ${c}aa`, marginTop:4}}>{p.total}</div>
      </div>
    </div>
  );
};

// Player scores — at the TOP (per feedback). Sorted, leader gold, active cyan.
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

// Shanghai chase banner
const ShanghaiBanner = () => (
  <div className={ONE_AWAY?'sh-glow':''} style={{padding:'12px 16px', border:`2px solid ${ONE_AWAY?YELLOW:`${YELLOW}55`}`, background:`${YELLOW}${ONE_AWAY?'18':'0a'}`, display:'flex', alignItems:'center', gap:12, animation:ONE_AWAY?'shGlow 1s ease-in-out infinite':'none'}}>
    <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:1, textShadow:`0 0 6px ${YELLOW}aa`}}>⚡ SHANGHAI</span>
    <span style={{flex:1, fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.8)', letterSpacing:1}}>{ONE_AWAY ? <>treff <b style={{color:YELLOW}}>T{TARGET}</b> for direkte seier!</> : <>S + D + T i én tur = direkte seier</>}</span>
    <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:ONE_AWAY?YELLOW:'#fff', textShadow:`0 0 6px ${YELLOW}88`}}>{GOT}/3</span>
  </div>
);

// The S/D/T chase cells — input AND chase tracker. Hit this turn → green ✓.
const CHASE = [
  { key:'single', cap:'SINGLE', lab:`${TARGET}` },
  { key:'double', cap:'DOUBLE', lab:`D${TARGET}` },
  { key:'triple', cap:'TRIPLE', lab:`T${TARGET}` },
];
const ChaseCells = ({ big }) => (
  <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:14, width:'100%', maxWidth:big?680:560}}>
    {CHASE.map(c=>{
      const hit = TURN_HITS[c.key];
      const need = !hit && ONE_AWAY;          // the one dart from Shanghai
      const col = hit?GREEN:CYAN;
      return (
        <div key={c.key} className={need?'sh-glow':''} style={{border:`${hit?3:2}px solid ${need?YELLOW:col}`, background:`${hit?GREEN:CYAN}${hit?'1c':'10'}`, boxShadow:`0 0 ${hit?18:14}px ${need?YELLOW:col}${hit?'66':'33'}`, padding:big?'22px 0 16px':'16px 0 12px', display:'flex', flexDirection:'column', alignItems:'center', gap:7, animation:need?'shGlow 1s ease-in-out infinite':'none'}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:hit?GREEN:need?YELLOW:c, letterSpacing:1.5}}>{c.cap}</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:big?40:32, color:hit?GREEN:col, textShadow:`0 0 12px ${hit?GREEN:col}aa`}}>{c.lab}</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:hit?GREEN:need?YELLOW:'rgba(255,255,255,0.4)', letterSpacing:1}}>{hit?'✓ TRUFFET':need?'← MANGLER':'—'}</div>
        </div>
      );
    })}
  </div>
);

// Round journey 1→N
const RoundLadder = ({ big }) => (
  <div style={{display:'flex', gap:big?10:6}}>
    {Array.from({length:ROUNDS_END},(_,i)=>i+1).map(n=>{
      const cur=n===ROUND, done=n<ROUND;
      const col=cur?CYAN:done?GREEN:'rgba(255,255,255,0.3)';
      return (
        <div key={n} style={{flex:cur&&big?1.6:1, textAlign:'center', padding:big?(cur?'16px 0':'12px 0'):'8px 0', border:`2px solid ${cur?CYAN:done?`${GREEN}55`:'rgba(255,255,255,0.12)'}`, background:cur?`${CYAN}18`:done?`${GREEN}08`:'transparent', boxShadow:cur?`0 0 12px ${CYAN}55`:'none'}}>
          {big && cur && <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>MÅL</div>}
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:big?(cur?30:15):13, color:col, textShadow:cur?`0 0 8px ${CYAN}`:'none', lineHeight:1.2}}>{n}</div>
          {done && !big && <div style={{fontFamily:'"VT323", monospace', fontSize:11, color:GREEN}}>✓</div>}
        </div>
      );
    })}
  </div>
);

// ════════════════════════════════════════════════════════════════
// A · CHASE  (recommended) — chase cells are hero + input
// ════════════════════════════════════════════════════════════════
const CockpitA = () => (
  <Frame>
    <TopBar/>
    <ActiveStrip/>
    <div style={{padding:'12px 16px 0'}}><Standings/></div>
    <div style={{padding:'12px 16px 0'}}><ShanghaiBanner/></div>
    <div style={{flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', minHeight:0, padding:'8px 16px 0'}}>
      <div style={{marginBottom:22, textAlign:'center'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.5)', letterSpacing:4}}>RUNDENS MÅL</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:60, color:YELLOW, lineHeight:1.1, textShadow:`0 0 24px ${YELLOW}aa`, marginTop:6}}>{TARGET}</div>
      </div>
      <ChaseCells big/>
    </div>
    <div style={{padding:'12px 16px 6px'}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.45)', letterSpacing:2, marginBottom:8}}>RUNDE-LØP</div>
      <RoundLadder/>
    </div>
    <ActionBar/>
  </Frame>
);

// ════════════════════════════════════════════════════════════════
// B · JOURNEY — the 1→N journey is the hero
// ════════════════════════════════════════════════════════════════
const CockpitB = () => (
  <Frame>
    <TopBar/>
    <ActiveStrip/>
    <div style={{padding:'12px 16px 0'}}><Standings/></div>
    <div style={{flex:1, display:'flex', flexDirection:'column', justifyContent:'center', minHeight:0, padding:'16px 16px 0', gap:18}}>
      <div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginBottom:12}}>RUNDE-LØP · 1 → {ROUNDS_END}</div>
        <RoundLadder big/>
      </div>
      <ShanghaiBanner/>
      <div style={{display:'flex', justifyContent:'center'}}><ChaseCells/></div>
    </div>
    <ActionBar/>
  </Frame>
);

// ════════════════════════════════════════════════════════════════
// C · SCORECARD — round×player history grid
// ════════════════════════════════════════════════════════════════
const ShScorecard = () => {
  const colT = `64px repeat(${PLAYERS.length}, 1fr)`;
  return (
    <div style={{display:'flex', flexDirection:'column', border:`2px solid ${MAGENTA}55`, flex:1, minHeight:0}}>
      <div style={{display:'grid', gridTemplateColumns:colT, background:`${MAGENTA}15`, borderBottom:`2px solid ${MAGENTA}55`}}>
        <div style={{padding:'9px 0', textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.55)', letterSpacing:1, alignSelf:'center', borderRight:`1px solid ${MAGENTA}33`}}>MÅL</div>
        {PLAYERS.map(p => (
          <div key={p.handle} style={{padding:'8px 4px', textAlign:'center', borderRight:`1px solid ${MAGENTA}22`, background:p.active?`${CYAN}1a`:'transparent'}}>
            <div style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:13, color:p.active?CYAN:PHOSPHOR, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{p.active&&'▶ '}{p.name}</div>
          </div>
        ))}
      </div>
      {Array.from({length:ROUNDS_END},(_,i)=>i+1).map((n,ri) => {
        const cur = n===ROUND, done = n<ROUND;
        return (
          <div key={n} style={{flex:1, display:'grid', gridTemplateColumns:colT, borderBottom: ri<ROUNDS_END-1?`1px solid ${MAGENTA}1c`:'none', background:cur?`${CYAN}10`:'transparent', minHeight:0, alignItems:'center', opacity:done?0.8:n>ROUND?0.5:1}}>
            <div style={{borderRight:`1px solid ${MAGENTA}33`, display:'flex', alignItems:'center', justifyContent:'center', gap:5, height:'100%'}}>
              {cur && <span style={{color:CYAN, fontFamily:'"Press Start 2P", monospace', fontSize:9}}>▶</span>}
              <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:cur?YELLOW:'rgba(255,210,0,0.7)', textShadow:cur?`0 0 6px ${YELLOW}88`:'none'}}>{n}</span>
            </div>
            {PLAYERS.map((p,pi)=>{
              const v = p.cells[ri], live = v==='LIVE';
              return (
                <div key={p.handle} style={{height:'100%', display:'flex', alignItems:'center', justifyContent:'center', borderRight: pi<PLAYERS.length-1?`1px solid ${MAGENTA}14`:'none', background:p.active&&cur?`${CYAN}14`:'transparent'}}>
                  {live
                    ? <span className="sh-pulse" style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:CYAN, textShadow:`0 0 8px ${CYAN}aa`, animation:'shPulse 0.9s ease-in-out infinite'}}>+{ACTIVE.turnPts}</span>
                    : v==null
                      ? <span style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.2)'}}>·</span>
                      : <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:p.active?'#fff':'rgba(255,255,255,0.82)'}}>{v}</span>}
                </div>
              );
            })}
          </div>
        );
      })}
      <div style={{display:'grid', gridTemplateColumns:colT, background:'#000', borderTop:`2px solid ${MAGENTA}55`}}>
        <div style={{padding:'10px 0', textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.7)', letterSpacing:1, borderRight:`1px solid ${MAGENTA}33`}}>SUM</div>
        {PLAYERS.map(p => { const lead=p===LEADER, col=p.active?CYAN:lead?YELLOW:'#fff'; return (
          <div key={p.handle} style={{padding:'9px 4px', textAlign:'center', borderRight:`1px solid ${MAGENTA}22`, background:p.active?`${CYAN}12`:'transparent'}}>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:17, color:col, textShadow:`0 0 8px ${col}aa`}}>{p.total}</div>
          </div>
        );})}
      </div>
    </div>
  );
};
const CockpitC = () => (
  <Frame>
    <TopBar/>
    <ActiveStrip/>
    <div style={{padding:'12px 16px 0'}}><ShanghaiBanner/></div>
    <div style={{flex:1, padding:'12px 16px 0', display:'flex', flexDirection:'column', minHeight:0}}><ShScorecard/></div>
    <div style={{padding:'12px 16px 6px', display:'flex', justifyContent:'center'}}><ChaseCells/></div>
    <ActionBar/>
  </Frame>
);

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
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Shanghai · chase</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Hvorfor A</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Inputen er bare S/D/T av rundens tall — så de tre cellene <b style={{color:'#2a251f'}}>er</b> samtidig Shanghai-jakten: de lyser grønt etter hvert som du treffer single, dobbel, trippel. Treff alle tre i én tur = <b style={{color:'#2a251f'}}>direkte seier</b>. Input og spenning er samme element. B gjør runde-løpet til helten; C er et full historikk-scorecard. Alle har scorer øverst + rene celler.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Farger (per rolle)</div>
      <SpecRow zone="Aktiv spiller · total + celler" val="#00E5FF" hex={CYAN}/>
      <SpecRow zone="Truffet denne turen · ✓" val="#3DFF8E" hex={GREEN}/>
      <SpecRow zone="Rundens mål · SHANGHAI-sjanse" val="#FFD200" hex={YELLOW}/>
      <SpecRow zone="Leder-total" val="#FFD200" hex={YELLOW}/>
      <SpecRow zone="Motstandere · standings" val="phosphor" hex={PHOSPHOR}/>
      <SpecRow zone="Ramme + linjer" val="#FF00AA" hex={MAGENTA}/>
      <SpecRow zone="MISS / chrome-accent" val="#FF7A00" hex={ORANGE}/>
      <SpecRow zone="BG + frame" val="#0A0014" hex={BG}/>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Input + Shanghai-logikk</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Runde k → mål = k (samme for alle). Tre celler = <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>recordThrow(single/double/triple)</code> → poeng = mult×k, akkumuleres. Treff <b style={{color:'#2a251f'}}>S + D + T i samme tur</b> → <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>isInstantShanghai</code> = direkte seier. Etter runde {ROUNDS_END} vinner høyest total (likt → uavgjort). Område: 1-7 / 1-9 / 1-20.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Arcade-cockpit','DOSSEDART-chrome: ArcadeFrame (CRT), topbar, active-strip, scorer ØVERST, chase-celler, runde-løp, action-bar. Samme byggeklosser som de andre modusene.'],
        ['2','Celler = jakt + input','Tre celler SINGLE/DOUBLE/TRIPLE av målet. Truffet denne turen → grønn + ✓. Når 2/3 → den siste pulser gult («← mangler») + banner «treff T{k} for seier». Rene celler, ingen «=N P».'],
        ['3','Scorer øverst','Standings-stripe rett under active-strip: 3 totaler, leder gul, aktiv cyan, fulle navn. Ingen forkortelser.'],
        ['4','Shanghai-banner','Gul stripe over cellene viser jakten (n/3). Lyser sterkt når 1 unna. Idet S+D+T fylles → full-skjerm «SHANGHAI! DIREKTE SEIER».'],
        ['5','Én farge-logikk','Aktiv=cyan, truffet=grønn, mål/leder/shanghai=gul, motstandere=phosphor. Ingen per-spiller-farger. Følger de andre modusene.'],
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
        <b>Konsistens:</b> samme chrome + farge-prinsipp som alle fem andre modusene. Det egne for Shanghai: de tre input-cellene er også Shanghai-jakten, med scorer øverst og rene celler — som besluttet i Splitscore-runden.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const ShanghaiCockpit = () => (
  <DCSection
    id="shanghai-directions"
    title="Shanghai — cockpit (3 retninger) · siste gamemode"
    subtitle="Shanghai: runder 1→N, alle skyter rundens tall, poeng = single/dobbel/trippel × tallet, akkumulert. Treff S + D + T av tallet i én tur = direkte seier («Shanghai!»). Input er bare S/D/T av tallet — så de tre cellene dobler som Shanghai-jakten. Scorer øverst + rene celler (som besluttet). Anbefalt: A · chase.">
    <DCArtboard id="sh-a" label="A · Chase (celler = jakt + input)  ← anbefalt" width={SH_W} height={SH_H}><CockpitA/></DCArtboard>
    <DCArtboard id="sh-b" label="B · Journey (runde-løpet som helt)" width={SH_W} height={SH_H}><CockpitB/></DCArtboard>
    <DCArtboard id="sh-c" label="C · Scorecard (full historikk)" width={SH_W} height={SH_H}><CockpitC/></DCArtboard>
    <DCArtboard id="sh-spec" label="Implementasjon · spec + tokens (retning A)" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.ShanghaiCockpit = ShanghaiCockpit;

// ── Locked final — direction A (chase) ──────────────────────────
const ShanghaiCockpitFinal = () => (
  <DCSection
    id="shanghai-final"
    title="Shanghai cockpit — final (chase)"
    subtitle="Valgt retning A. De tre cellene er både input og Shanghai-jakten: de lyser grønt når du treffer single/dobbel/trippel av rundens tall, og en gul banner teller mot direkte seier (her 2/3 — én T3 unna). Scorer øverst, rene celler, runde-løp nederst. Samme chrome + farge-logikk som de fem andre modusene.">
    <DCArtboard id="shf-cockpit" label="Cockpit · Shanghai · chase" width={SH_W} height={SH_H}><CockpitA/></DCArtboard>
    <DCArtboard id="shf-spec" label="Implementasjon · spec + tokens" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.ShanghaiCockpitFinal = ShanghaiCockpitFinal;
