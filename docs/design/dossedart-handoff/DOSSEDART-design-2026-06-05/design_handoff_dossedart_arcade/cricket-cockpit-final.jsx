// DOSSEDART — Cricket cockpit FINAL (input model A · matrix-tap)
// Picked: A. The scoreboard IS the input — the active player's column
// expands into tappable S/D/T cells per target; opponents show read-only
// neon glyph marks (/ X ⊗). Aligned to the X01 G decisions.
//
// FIXES BAKED IN (vs current classic Material cricket screen):
//   1. Full arcade chrome — replaces AppBar + DataTable + M3 buttons with
//      the DOSSEDART cockpit (CRT frame, topbar, active strip, action bar).
//   2. Matrix-tap input — active column = S/D/T cells; feeds the existing
//      engine API onHit(segment, multiplier). No new game logic.
//   3. Colors.green → tokens — closed mark = DossedartTokens.green; marks
//      render in each player's OWN colour (player_colors.dart), not cs.primary.
//   4. Per-player accent — active player glows in their own colour.
//   5. Chrome = magenta — matrix lines/frame magenta, target labels yellow,
//      closed green. No hardcoded Material colours.

const K_W = 820, K_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#1a0030';

const TARGETS = ['20','19','18','17','16','15','BULL'];

// No per-player colours. Active thrower glows in ONE highlight (cyan);
// everyone else renders in a single phosphor tone — like the home screen.
const ACTIVE_C = CYAN;
const PHOSPHOR = '#D9D2C2';

const PLAYERS = [
  { handle:'JON', name:'Jonas',   active:true, dartIdx:1, points:41,
    last:'T18', marks:{'20':3,'19':3,'18':2,'17':1,'16':0,'15':0,'BULL':0} },
  { handle:'AND', name:'Andreas', points:34,
    marks:{'20':3,'19':2,'18':3,'17':0,'16':0,'15':0,'BULL':0} },
  { handle:'MIA', name:'Mia',     points:12,
    marks:{'20':3,'19':1,'18':0,'17':0,'16':0,'15':0,'BULL':0} },
];
const ACTIVE = PLAYERS.find(p => p.active);
const ACTIVE_IDX = PLAYERS.findIndex(p => p.active);
const colorFor = (active) => active ? ACTIVE_C : PHOSPHOR;
const markGlyph = (n) => n === 0 ? '' : n === 1 ? '/' : n === 2 ? 'X' : '⊗';

// ── Chrome ──────────────────────────────────────────────────────
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
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>CRICKET · STANDARD</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>RND 7</div>
  </div>
);

const DartDots = ({ idx=2, color=YELLOW, size=12 }) => (
  <div style={{display:'flex', gap:6}}>
    {[0,1,2].map(i => (
      <div key={i} style={{width:size, height:size, borderRadius:'50%', background:i<idx?color:'transparent', border:`2px solid ${color}`, boxShadow:i<idx?`0 0 8px ${color}aa`:'none'}}></div>
    ))}
  </div>
);

// ── Active strip (single highlight — no per-player colours) ─────
const ActiveStrip = () => {
  const p = ACTIVE, c = ACTIVE_C;
  return (
    <div style={{padding:'14px 22px', display:'flex', alignItems:'center', gap:14, background:`linear-gradient(90deg, ${c}1f 0%, transparent 100%)`, borderBottom:`3px solid ${c}`, boxShadow:`0 0 18px ${c}44`, position:'relative', zIndex:6}}>
      <div style={{width:52, height:52, background:BG, border:`3px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, textShadow:`0 0 8px ${c}aa`, flexShrink:0, boxShadow:`0 0 14px ${c}55`}}>{p.handle}</div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:10}}>
          <span style={{color:c, fontFamily:'"Press Start 2P", monospace', fontSize:14, letterSpacing:1.5, textShadow:`0 0 6px ${c}aa`}}>▶ {p.name.toUpperCase()}</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>DART {p.dartIdx + 1} / 3</span>
        </div>
        <div style={{display:'flex', alignItems:'center', gap:10, marginTop:7}}>
          <DartDots idx={p.dartIdx} color={c}/>
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.7)', letterSpacing:2}}>LAST · <span style={{color:GREEN, fontFamily:'"Press Start 2P", monospace', fontSize:10}}>{p.last}</span></div>
        </div>
      </div>
      <div style={{textAlign:'right'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>POINTS</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:40, color:c, lineHeight:1, textShadow:`0 0 16px ${c}aa`, marginTop:4}}>{p.points}</div>
      </div>
    </div>
  );
};

// ── Read-only marks (/ = 1, X = 2, ⊗ = closed) ──────────────────
const GlyphMarks = ({ n, color }) => {
  if (n === 0) return <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.18)'}}>·</div>;
  if (n >= 3) return <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:22, color:GREEN, textShadow:`0 0 10px ${GREEN}aa`, lineHeight:1}}>⊗</div>;
  return <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:22, color, textShadow:`0 0 8px ${color}aa`, lineHeight:1}}>{n === 1 ? '/' : 'X'}</div>;
};

const PlayerHeader = ({ p, active }) => {
  const c = colorFor(active);
  return (
    <div style={{padding:'10px 6px', borderRight:`1px solid ${MAGENTA}33`, display:'flex', flexDirection:'column', alignItems:'center', gap:3, background:active?`${c}1c`:'transparent', position:'relative'}}>
      {active && <div style={{position:'absolute', top:-1, left:0, right:0, height:3, background:c, boxShadow:`0 0 8px ${c}`}}></div>}
      <div style={{display:'flex', alignItems:'center', gap:5}}>
        <span style={{color:c, fontFamily:'"Press Start 2P", monospace', fontSize:active?12:11, letterSpacing:1, textShadow:`0 0 6px ${c}aa`}}>{p.handle}</span>
        {active && <span style={{color:c, fontFamily:'"Press Start 2P", monospace', fontSize:10, textShadow:`0 0 6px ${c}aa`}}>▶</span>}
      </div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:active?20:16, color:c, letterSpacing:-.5, textShadow:`0 0 8px ${c}aa`}}>{p.points}</div>
    </div>
  );
};

// ── Active column cell — the tappable S/D/T input (FIX #2) ───────
// A target is only DEAD when ALL players have closed it. If only the
// active player has closed it, the cells stay tappable — those darts now
// score points. No hints/suggestions, just the raw S/D/T input.
const ActiveCell = ({ t, marks, closedByAll }) => {
  const c = ACTIVE_C;
  const isBull = t === 'BULL';
  if (closedByAll) {
    return (
      <div style={{borderRight:`1px solid ${MAGENTA}33`, display:'flex', alignItems:'center', justifyContent:'center', opacity:0.3}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:26, color:PHOSPHOR, lineHeight:1}}>⊗</div>
      </div>
    );
  }
  const ownClosed = marks >= 3;
  const subs = isBull
    ? [ { label:'BULL', m:1 }, { label:'D-BULL', m:2 }, { label:'—', m:0, disabled:true } ]
    : [ { label:t, m:1 }, { label:`D${t}`, m:2 }, { label:`T${t}`, m:3 } ];
  const Sub = ({ label, disabled }) => (
    <div style={{flex:1, background:disabled?'transparent':`${c}0d`, borderLeft:`1px dashed ${c}55`, display:'flex', alignItems:'center', justifyContent:'center', opacity:disabled?0.3:1, padding:'0 4px'}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:label.length>3?12:14, color:disabled?'rgba(255,255,255,0.35)':c, letterSpacing:.5, textShadow:disabled?'none':`0 0 8px ${c}aa`, textAlign:'center'}}>{label}</div>
    </div>
  );
  return (
    <div style={{borderRight:`1px solid ${MAGENTA}33`, background:`${c}12`, display:'flex'}}>
      {/* leading badge: active player's own marks on this target */}
      <div style={{width:30, flexShrink:0, display:'flex', alignItems:'center', justifyContent:'center'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:ownClosed?GREEN:c, textShadow:`0 0 8px ${ownClosed?GREEN:c}aa`, lineHeight:1}}>{markGlyph(marks) || '·'}</div>
      </div>
      {subs.map(s => <Sub key={s.label} {...s}/>)}
    </div>
  );
};

// ── Matrix (scoreboard + input in one) ──────────────────────────
const Matrix = () => {
  const leftOpps  = PLAYERS.slice(0, ACTIVE_IDX);
  const rightOpps = PLAYERS.slice(ACTIVE_IDX + 1);
  const colTemplate = ['60px', ...leftOpps.map(()=>'1fr'), '2.7fr', ...rightOpps.map(()=>'1fr')].join(' ');
  return (
    <div style={{padding:'16px 16px 0', display:'flex', flexDirection:'column', flex:1, minHeight:0}}>
      <div style={{flex:1, display:'flex', flexDirection:'column', border:`2px solid ${MAGENTA}55`, minHeight:0}}>
        <div style={{display:'grid', gridTemplateColumns:colTemplate, background:`${MAGENTA}15`, borderBottom:`2px solid ${MAGENTA}55`}}>
          <div style={{padding:'10px 0', textAlign:'center', borderRight:`1px solid ${MAGENTA}33`, fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.55)', letterSpacing:1.5, alignSelf:'center'}}>TGT</div>
          {leftOpps.map(p => <PlayerHeader key={p.handle} p={p}/>)}
          <PlayerHeader p={ACTIVE} active/>
          {rightOpps.map(p => <PlayerHeader key={p.handle} p={p}/>)}
        </div>
        {TARGETS.map((t, ti) => {
          const closedByAll = PLAYERS.every(p => p.marks[t] >= 3);
          return (
            <div key={t} style={{flex:1, display:'grid', gridTemplateColumns:colTemplate, borderBottom: ti<TARGETS.length-1?`1px solid ${MAGENTA}22`:'none', opacity:closedByAll?0.3:1, minHeight:0}}>
              <div style={{borderRight:`1px solid ${MAGENTA}33`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:t==='BULL'?13:20, color:closedByAll?'rgba(255,255,255,0.4)':YELLOW, letterSpacing:1, textShadow:closedByAll?'none':`0 0 8px ${YELLOW}88`}}>{t}</div>
              {leftOpps.map(p => (
                <div key={p.handle} style={{borderRight:`1px solid ${MAGENTA}22`, display:'flex', alignItems:'center', justifyContent:'center'}}><GlyphMarks n={p.marks[t]} color={PHOSPHOR}/></div>
              ))}
              <ActiveCell t={t} marks={ACTIVE.marks[t]} closedByAll={closedByAll}/>
              {rightOpps.map((p, i) => (
                <div key={p.handle} style={{borderRight: i<rightOpps.length-1?`1px solid ${MAGENTA}22`:'none', display:'flex', alignItems:'center', justifyContent:'center'}}><GlyphMarks n={p.marks[t]} color={PHOSPHOR}/></div>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
};

const ActionBar = () => (
  <div style={{padding:'12px 16px 16px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:10, position:'relative', zIndex:6}}>
    <div style={{flex:1, padding:'14px', border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:2, padding:'14px', background:ORANGE, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:BG, letterSpacing:2, textAlign:'center', boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:1, padding:'14px', border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5, textAlign:'center'}}>⋯ MENU</div>
  </div>
);

const Cockpit = () => (
  <Frame>
    <TopBar/>
    <ActiveStrip/>
    <Matrix/>
    <ActionBar/>
  </Frame>
);

// ── Implementation spec card ────────────────────────────────────
const SpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}></div>
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);

const SpecCard = () => (
  <div style={{width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:16, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · klar for kode</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:28, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Cricket · matrix-tap — spec</div>
    </div>

    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Farger (per rolle)</div>
      <SpecRow zone="Mål-label (åpen)" val="#FFD200" hex="#FFD200"/>
      <SpecRow zone="Aktiv spiller · kolonne + strip" val="#00E5FF" hex={CYAN}/>
      <SpecRow zone="Motstandere · marks + header" val="phosphor" hex={PHOSPHOR}/>
      <SpecRow zone="Lukket ⊗ (3 marks)" val="#3DFF8E" hex={GREEN}/>
      <SpecRow zone="Matrix-linjer + ramme" val="#FF00AA" hex={MAGENTA}/>
      <SpecRow zone="MISS / chrome-accent" val="#FF7A00" hex={ORANGE}/>
      <SpecRow zone="BG + frame" val="#0A0014" hex={BG}/>
    </div>

    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Input + lukke-logikk</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Aktiv spillers kolonne = tappbare <b style={{color:'#2a251f'}}>S/D/T-celler</b> → <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>engine.applyHit(segment, multiplier)</code>. Et mål er kun <b style={{color:'#2a251f'}}>dødt når ALLE har lukket det</b> (<code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>isClosedByAll</code>) — har du selv lukket men ikke motstanderne, scorer tappet poeng og cellene er fortsatt aktive. Ingen hint/forslag. Motstandere read-only.</div>
    </div>

    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Feil løst + best practice</div>
      {[
        ['1','Lukket ≠ dødt','Celler dør kun når isClosedByAll(target). Egen-lukket + åpen hos motstander → cellene tapper fortsatt og scorer poeng (overflow). Liten ⊗-badge viser egen lukking; målet er aktivt til alle har lukket.'],
        ['2','Arcade-cockpit','Erstatt AppBar + DataTable + M3-knapper med DOSSEDART-chrome: ArcadeFrame (CRT), topbar, active-strip, matrix, action-bar. Samme byggeklosser som X01.'],
        ['3','Én farge-logikk','Aktiv spiller = cyan highlight, motstandere = phosphor. Ingen per-spiller-farger (ingen regnbue). Følger home-skjermens active/inactive-mønster.'],
        ['4','Colors.green → token','cricket_scoreboard: lukket mark = DossedartTokens.green. Ingen Material-literals (cs.primary / Colors.green) igjen.'],
        ['5','Ingen forslag','Brettet coacher ikke — ingen «CLOSES»/neste-kast-hint. Cellene er ren input. Mål-labels gul, matrix-linjer magenta.'],
      ].map(([n,t,b])=>(
        <div key={n} style={{display:'flex', gap:11, padding:'9px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{flexShrink:0, width:22, height:22, borderRadius:'50%', background:'#2a8a52', color:'#fff', display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"JetBrains Mono", monospace', fontSize:12, fontWeight:700}}>{n}</div>
          <div style={{flex:1}}>
            <div style={{fontFamily:'"Inter", sans-serif', fontSize:13.5, fontWeight:700, color:'#2a251f', marginBottom:2}}>{t}</div>
            <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.5, color:'#5a544a'}}>{b}</div>
          </div>
        </div>
      ))}
    </div>

    <div style={{marginTop:'auto', padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#2a4a36'}}>
        <b>Konsistens med X01:</b> samme chrome (topbar/active-strip/action-bar) og samme farge-prinsipp — chrome magenta, aktiv = cyan highlight, gul = label/score, grønn = lukket/success, oransje = MISS. Ulik input (matrix vs brett) er bevisst: Cricket har 7 mål, X01 har hele brettet.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const CricketCockpitFinal = () => (
  <>
    <DCSection
      id="cricket-final"
      title="Cricket cockpit — final (matrix-tap)"
      subtitle="Valgt input-modell A: scoreboardet er inputen. Aktiv spillers kolonne (cyan = den som kaster) utvider seg til tappbare S/D/T-celler; motstandere viser read-only phosphor-glyphs (/ X ⊗). Et mål er kun dødt når ALLE har lukket det — egen-lukket scorer fortsatt poeng. Ingen per-spiller-farger, ingen kast-forslag.">
      <DCArtboard id="ck-cockpit" label="Cockpit · Cricket · matrix-tap" width={K_W} height={K_H}><Cockpit/></DCArtboard>
      <DCArtboard id="ck-spec" label="Implementasjon · spec + tokens" width={680} height={1180}><SpecCard/></DCArtboard>
    </DCSection>
  </>
);

window.CricketCockpitFinal = CricketCockpitFinal;
