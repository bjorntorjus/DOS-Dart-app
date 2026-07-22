// DOSSEDART — X01 cockpit FINAL (direction G · TWILIGHT)
// Picked: G. This file is the handoff-ready proposal — G board dropped into
// the real cockpit chrome, with every review FIX applied + best practice.
//
// FIXES BAKED IN (vs current v1.8.0):
//   1. Board bg solid black (#0A0014), not surface-purple → clean contrast.
//   2. Active-card accent = the player's OWN colour (identity), not a
//      hardcoded magenta for everyone.
//   3. Legs wired in the top bar (L 1/3), not the static L 1/1.
//   4. Single magenta frame — the painter's own border ring is dropped;
//      only the container glow remains (no double edge).
//   5. Numbers white on the dark rim band; geometry identical to the app.

const G_W = 820, G_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const PURPLE  = '#7B3FFF';
const RED     = '#FF3050';
const GREEN   = '#3DFF8E';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#1a0030';
const PHOSPHOR= '#D9D2C2';

// ── G · TWILIGHT board palette ──────────────────────────────────
const TWI = {
  boardBg: '#000',
  singles: ['#1e0c40', '#321760'],   // twilight purple felt, dark/light
  ring:    ['#1fb0c9', '#c72e94'],    // medium cyan / magenta (alt per seg)
  bull:    YELLOW,                     // the one bright pop
  bullStroke: ORANGE,
  dbull:   RED,
  dbullStroke: YELLOW,
  spoke:   'rgba(0,0,0,0.6)',
  number:  '#fff',
  rim:     'rgba(255,0,170,0.4)',
};

// Real app radial proportions (dossedart_x01_dartboard.dart).
const R_DBULL = 0.05, R_BULL = 0.12, R_TRI_I = 0.47, R_TRI_O = 0.58;
const R_DBL_I = 0.82, R_DBL_O = 0.95, R_RIM = 1.00, R_NUM = 0.975;
const SEGMENTS = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5];

const wedge = (cx, cy, rIn, rOut, a1, a2) => {
  const px = (r,a)=>cx+r*Math.cos(a), py=(r,a)=>cy+r*Math.sin(a);
  const large = (a2-a1) > Math.PI ? 1 : 0;
  return [
    `M ${px(rIn,a1)} ${py(rIn,a1)}`, `L ${px(rOut,a1)} ${py(rOut,a1)}`,
    `A ${rOut} ${rOut} 0 ${large} 1 ${px(rOut,a2)} ${py(rOut,a2)}`,
    `L ${px(rIn,a2)} ${py(rIn,a2)}`,
    `A ${rIn} ${rIn} 0 ${large} 0 ${px(rIn,a1)} ${py(rIn,a1)}`, 'Z',
  ].join(' ');
};

// ── Dartboard (G only · no painter border ring) ─────────────────
const Dartboard = ({ size = 600 }) => {
  const cx = size/2, cy = size/2, R = size*0.47;
  const seg = (2*Math.PI)/20;
  const segAngles = SEGMENTS.map((_, i) => {
    const c = -Math.PI/2 + i*seg;
    return [c - seg/2, c + seg/2];
  });
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{display:'block'}}>
      <defs>
        <radialGradient id="twi-gloss" cx="50%" cy="50%">
          <stop offset="0%" stopColor="rgba(255,255,255,0.05)"/>
          <stop offset="70%" stopColor="rgba(255,255,255,0)"/>
        </radialGradient>
      </defs>
      <circle cx={cx} cy={cy} r={R*R_RIM} fill={TWI.boardBg}/>
      {/* inner singles */}
      {segAngles.map(([a1,a2],i)=>(
        <path key={`is${i}`} d={wedge(cx,cy,R_BULL*R,R_TRI_I*R,a1,a2)} fill={TWI.singles[i%2]}/>
      ))}
      {/* triple */}
      {segAngles.map(([a1,a2],i)=>(
        <path key={`t${i}`} d={wedge(cx,cy,R_TRI_I*R,R_TRI_O*R,a1,a2)} fill={TWI.ring[i%2]}/>
      ))}
      {/* outer singles */}
      {segAngles.map(([a1,a2],i)=>(
        <path key={`os${i}`} d={wedge(cx,cy,R_TRI_O*R,R_DBL_I*R,a1,a2)} fill={TWI.singles[i%2]}/>
      ))}
      {/* double */}
      {segAngles.map(([a1,a2],i)=>(
        <path key={`d${i}`} d={wedge(cx,cy,R_DBL_I*R,R_DBL_O*R,a1,a2)} fill={TWI.ring[i%2]}/>
      ))}
      {/* spokes */}
      {segAngles.map(([a1],i)=>{
        const x1=cx+Math.cos(a1)*R_BULL*R, y1=cy+Math.sin(a1)*R_BULL*R;
        const x2=cx+Math.cos(a1)*R_DBL_O*R, y2=cy+Math.sin(a1)*R_DBL_O*R;
        return <line key={`sp${i}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke={TWI.spoke} strokeWidth="1"/>;
      })}
      {/* dark rim band */}
      <circle cx={cx} cy={cy} r={(R_DBL_O+(R_RIM-R_DBL_O)/2)*R} fill="none" stroke={BG} strokeWidth={(R_RIM-R_DBL_O)*R}/>
      {/* bull + d-bull (the bright pop) */}
      <circle cx={cx} cy={cy} r={R_BULL*R} fill={TWI.bull} stroke={TWI.bullStroke} strokeWidth="2"/>
      <circle cx={cx} cy={cy} r={R_DBULL*R} fill={TWI.dbull} stroke={TWI.dbullStroke} strokeWidth="1.5"/>
      {/* numbers — white on dark rim */}
      {SEGMENTS.map((n,i)=>{
        const c=-Math.PI/2+i*seg, x=cx+Math.cos(c)*R_NUM*R, y=cy+Math.sin(c)*R_NUM*R;
        return <text key={`n${i}`} x={x} y={y+4} fontFamily="'Press Start 2P', monospace" fontSize="11" fill={TWI.number} textAnchor="middle">{n}</text>;
      })}
      <circle cx={cx} cy={cy} r={R*R_RIM} fill="url(#twi-gloss)" pointerEvents="none"/>
    </svg>
  );
};

// ── Active player (per-player accent — FIX #2) ──────────────────
const ACTIVE = {
  handle:'JON', name:'Jonas', accent:CYAN,
  remaining:170, dartIdx:2,
  last:'T20 · T20 · —', lastSum:120,
  checkout:'T20 › T20 › D-BULL',
};

const Frame = ({ children }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:G_W, height:G_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', position:'relative', overflow:'hidden'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
      {children}
    </div>
  );
};

const TopBar = () => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>X01 · 501 · D-OUT</div>
    {/* FIX #3 — real legs, not static L 1/1 */}
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>L 1/3 · RND 7</div>
  </div>
);

const ActiveCard = ({ p }) => (
  <div style={{margin:'14px 14px 0', padding:'14px 18px', position:'relative',
               border:`3px solid ${p.accent}`,
               background:`linear-gradient(180deg, ${p.accent}1a 0%, ${p.accent}05 100%)`,
               boxShadow:`0 0 16px ${p.accent}40`}}>
    <div style={{position:'absolute', top:-9, left:18, padding:'3px 9px', background:p.accent, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:9, letterSpacing:1.5, boxShadow:`0 0 8px ${p.accent}aa`}}>▶ NOW THROWING</div>
    <div style={{display:'flex', alignItems:'flex-start', gap:14}}>
      <div style={{width:56, height:56, background:BG, border:`3px solid ${p.accent}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:15, color:p.accent, textShadow:`0 0 8px ${p.accent}aa`, flexShrink:0, boxShadow:`0 0 12px ${p.accent}55`}}>{p.handle}</div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:18, color:'#fff', letterSpacing:2, lineHeight:1, marginTop:4}}>{p.name.toUpperCase()}</div>
        <div style={{display:'flex', alignItems:'center', gap:10, marginTop:8}}>
          <div style={{display:'flex', gap:6}}>
            {[0,1,2].map(i=>(
              <div key={i} style={{width:10, height:10, background:i<p.dartIdx?p.accent:'transparent', border:`2px solid ${p.accent}`, boxShadow:i<p.dartIdx?`0 0 6px ${p.accent}aa`:'none'}}></div>
            ))}
          </div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.55)', letterSpacing:1}}>DART {p.dartIdx}/3</div>
        </div>
      </div>
      <div style={{textAlign:'right'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.6)', letterSpacing:1.5}}>REMAINING</div>
        {/* FIX #2 — remaining number = player accent, not magenta */}
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:58, color:p.accent, lineHeight:1, textShadow:`0 0 16px ${p.accent}aa`, letterSpacing:-2, marginTop:4}}>{p.remaining}</div>
      </div>
    </div>
    <div style={{display:'flex', alignItems:'center', gap:8, marginTop:10, padding:'8px 12px', borderTop:`1px solid ${p.accent}66`}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.6)', letterSpacing:1.5}}>LAST</div>
      <div style={{flex:1, textAlign:'center', fontFamily:'"VT323", monospace', fontSize:20, color:YELLOW, letterSpacing:1.5}}>{p.last}</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:YELLOW, letterSpacing:1}}>= {p.lastSum}</div>
    </div>
    <div style={{marginTop:10, padding:'8px 10px', background:`${GREEN}10`, border:`2px solid ${GREEN}`, boxShadow:`0 0 14px ${GREEN}40`, textAlign:'center'}}>
      <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:GREEN, letterSpacing:1}}>▶ {p.checkout}</span>
    </div>
  </div>
);

const ActionBar = () => (
  <div style={{position:'absolute', left:0, right:0, bottom:0, padding:'12px 14px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:10, zIndex:6}}>
    <div style={{flex:1, padding:'14px', background:'transparent', border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1.5, textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:2, padding:'14px', background:ORANGE, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:BG, letterSpacing:2, textAlign:'center', boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:1, padding:'14px', background:'transparent', border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5, textAlign:'center'}}>⋯ MENU</div>
  </div>
);

// Subtle corner affordance — signals the whole field around the circle
// is a tappable MISS zone, without the boxy frame.
const MissCorner = ({ pos }) => (
  <div style={{position:'absolute', ...pos, fontFamily:'"Press Start 2P", monospace', fontSize:9, color:MAGENTA, opacity:0.3, letterSpacing:1, pointerEvents:'none'}}>✗ MISS</div>
);

// ── Full cockpit ────────────────────────────────────────────────
const Cockpit = () => (
  <Frame>
    <TopBar/>
    <ActiveCard p={ACTIVE}/>
    {/* Board zone — circle maximized; ALL surrounding field is tappable
        MISS (no boxed frame). Corner hints signal the dead zone. */}
    <div style={{position:'absolute', left:0, right:0, top:330, bottom:66, display:'flex', alignItems:'center', justifyContent:'center'}}>
      {/* glow so the circle reads against black */}
      <div style={{position:'absolute', width:740, height:740, borderRadius:'50%', boxShadow:`0 0 70px ${MAGENTA}3a`, pointerEvents:'none'}}></div>
      <MissCorner pos={{top:6, left:18}}/>
      <MissCorner pos={{top:6, right:18}}/>
      <MissCorner pos={{bottom:6, left:18}}/>
      <MissCorner pos={{bottom:6, right:18}}/>
      <Dartboard size={760}/>
    </div>
    <ActionBar/>
  </Frame>
);

// ── Board detail (maximized · surrounding field = MISS) ─────────
const BoardDetail = () => (
  <div style={{width:680, height:680, background:BG, position:'relative', display:'flex', alignItems:'center', justifyContent:'center'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:`repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', width:600, height:600, borderRadius:'50%', boxShadow:`0 0 70px ${MAGENTA}3a`, pointerEvents:'none'}}></div>
    <MissCorner pos={{top:14, left:22}}/>
    <MissCorner pos={{top:14, right:22}}/>
    <MissCorner pos={{bottom:14, left:22}}/>
    <MissCorner pos={{bottom:14, right:22}}/>
    <Dartboard size={620}/>
  </div>
);

// ── Implementation spec card (paper) ────────────────────────────
const Chip = ({ c, label }) => (
  <div style={{display:'flex', alignItems:'center', gap:7, padding:'5px 9px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
    <div style={{width:14, height:14, background:c, border:'1px solid rgba(0,0,0,0.25)', boxShadow:`0 0 6px ${c}55`}}></div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, color:'#2a251f'}}>{label}</div>
  </div>
);

const SpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}></div>
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);

const SpecCard = () => (
  <div style={{width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:18, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · klar for kode</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:30, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>G · TWILIGHT — spec</div>
    </div>

    {/* Board tokens */}
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Brett-farger (per sone)</div>
      <SpecRow zone="Single — mørk (annenhver seg.)" val="#1E0C40" hex="#1E0C40"/>
      <SpecRow zone="Single — lys (annenhver seg.)" val="#321760" hex="#321760"/>
      <SpecRow zone="Triple + Double — cyan (mørk seg.)" val="#1FB0C9" hex="#1FB0C9"/>
      <SpecRow zone="Triple + Double — magenta (lys seg.)" val="#C72E94" hex="#C72E94"/>
      <SpecRow zone="Bull — gull (pop)" val="#FFD200" hex="#FFD200"/>
      <SpecRow zone="Bull-kant — oransje" val="#FF7A00" hex="#FF7A00"/>
      <SpecRow zone="D-Bull — rød" val="#FF3050" hex="#FF3050"/>
      <SpecRow zone="Brett-bg + rim" val="#0A0014" hex="#0A0014"/>
      <SpecRow zone="Tall" val="#FFFFFF" hex="#FFFFFF"/>
    </div>

    {/* Geometry note */}
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Geometri — uendret</div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, lineHeight:1.6, color:'#5a544a'}}>kDBullR .05 · kBullR .12 · kInnerSingleR .47 · kTripleR .58 · kOuterSingleR .82 · kDoubleR .95</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', marginTop:6, lineHeight:1.5}}>Kun fargene i <b style={{color:'#2a251f'}}>_DartboardPainter</b> endres. Singles og ringer alternerer på <b style={{color:'#2a251f'}}>(i % 2)</b> som i dag — cyan på mørk seg., magenta på lys.</div>
    </div>

    {/* Fixes */}
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Feil løst + best practice</div>
      {[
        ['1','Brett-bg → svart','I painteren: fyll disc-en med DossedartTokens.bg (#0A0014), ikke surface. Singles blir rene felt.'],
        ['2','Per-spiller accent','game_screen.dart: send spillerens egen farge (player_colors.dart) som accentColor til ActiveCard — ikke hardkodet magenta. Border + REMAINING-tallet følger spilleren.'],
        ['3','Legs i topbaren','DossedartX01TopBar får ekte legIndex/legCount fra match-state. Skjul «L n/m» hvis kampen er single-leg.'],
        ['4','Brett maksimert · ramme fjernet','Dropp den firkantede magenta-rammen + padding. Sirkelen fyller bredden (AspectRatio 1 → ~760px på testbrettet). Painterens egen border-ring fjernes også — kun en svak glow bak sirkelen.'],
        ['5','Hele feltet rundt = MISS','GestureDetector dekker hele firkanten; r > kDoubleR → DartZone.miss(). Sett HitTestBehavior.opaque så hjørner + sider registrerer trykk (fikser QA-buggen). Diskré «✗ MISS»-hint i hjørnene.'],
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

    {/* Chrome vs player note */}
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#2a4a36'}}>
        <b>Farge-prinsipp:</b> chrome (topbar, UNDO) forblir magenta. Active-card + REMAINING-tallet bruker <b>spillerens egen farge</b> for identitet. Gul = LAST/score-label, grønn = checkout, oransje = MISS/bull. Brettet bærer kun cyan + magenta + purple felt → ingen farge får «feil rolle».
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const X01CockpitFinal = () => (
  <>
    <DCSection
      id="cockpit-final"
      title="X01 cockpit — final (G · TWILIGHT)"
      subtitle="Valgt retning G droppet inn i den ekte cockpiten, med alle review-FIX på plass: svart brett-bg, per-spiller accent-farge (her cyan for Jonas), legs i topbaren. Brettet er nå MAKSIMERT — den firkantede ramma er borte, sirkelen fyller bredden, og hele feltet rundt (hjørner + sider) er klikkbar MISS-sone. Kun fargene endres ved port; geometrien er kode-eksakt.">
      <DCArtboard id="cf-cockpit" label="Cockpit · G · maksimert brett" width={G_W} height={G_H}><Cockpit/></DCArtboard>
      <DCArtboard id="cf-board" label="Brett · detalj + miss-sone" width={680} height={680}><BoardDetail/></DCArtboard>
      <DCArtboard id="cf-spec" label="Implementasjon · spec + tokens" width={680} height={1180}><SpecCard/></DCArtboard>
    </DCSection>
  </>
);

window.X01CockpitFinal = X01CockpitFinal;
