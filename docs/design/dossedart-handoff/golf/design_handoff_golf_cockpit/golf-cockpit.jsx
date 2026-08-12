// DOSSEDART — Golf cockpit · holes 1–18, lowest strokes wins
// ───────────────────────────────────────────────────────────────
// Reuses the DOSSEDART cockpit skeleton (Frame + scanlines, TopBar,
// ActionBar chrome) and ATC's S/D/T target-zone input. Golf plays the
// numbers 1–18 as holes; the LAST dart thrown counts, so each hole is a
// press-your-luck: LOCK IN your strokes or risk another dart.
//
// Stroke values: Triple = 1 (ACE) · Double = 2 (BIRDIE) · Single = 3 (PAR)
//                · Miss = 5 (BOGEY). Par is 3.
//
// What is NEW for Golf (design effort here):
//   • hole context — HOLE 7 · PAR 3 + LYING n (press-your-luck lie)
//   • the LOCK IN button — a FOURTH ActionBar action (only mode with one)
//   • the SCORECARD — hole-by-hole grid (inline strip + full sheet)
//   • ACE celebration, locked-in / bogey states, sudden death
//   • home-tile (Golf lit), setup (9/18 course selector), post-game podium
//
// Winner: per revised spec (1UP QA lesson 2026-07-16) the POST-GAME screen
// is the SOLE winner surface — there is NO in-cockpit winner overlay.
// Brand accent: existing GREEN token (no new token; brief §4 Golf accent).
// UI strings English (Norwegian-string guard). Terminology: LOCK IN.

const GF_W = 820, GF_H = 1180;

const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', BG='#0a0014', SURFACE='#1a0030',
      PHOSPHOR='#D9D2C2';
const GOLF = GREEN;   // Golf mode brand accent (existing token, per brief)

// stroke → golf label + colour
const GF_TERM = {
  1: { term:'ACE',    col:CYAN },
  2: { term:'BIRDIE', col:GREEN },
  3: { term:'PAR',    col:PHOSPHOR },
  4: { term:'BOGEY',  col:ORANGE },
  5: { term:'BOGEY',  col:RED },
};
const PAR = 3;

// ── shell chrome — identical pattern to X01 / ATC cockpit ────────
const gfScan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const GFFrame = ({ children }) => (
  <div style={{width:GF_W, height:GF_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:gfScan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {children}
  </div>
);
const GFTopBar = ({ hole, holes, sudden }) => (
  <div style={{padding:'14px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:GOLF, letterSpacing:2, textShadow:`0 0 6px ${GOLF}88`}}>⛳ GOLF{sudden?' · SUDDEN DEATH':''}</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>{sudden?'PLAYOFF':`HOLE ${hole}/${holes}`}</div>
  </div>
);

// ── ActionBar — Golf adds the LOCK IN button (fourth action) ─────
// disabled before dart 1; hero-green when enabled. Only mode with a 4th.
const GFActionBar = ({ lockable }) => (
  <div style={{position:'absolute', left:0, right:0, bottom:0, padding:'12px 14px 16px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:9, zIndex:6}}>
    <div style={{flex:1, padding:'14px 8px', border:`2px solid ${MAGENTA}`, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'#fff', letterSpacing:1, textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:1.3, padding:'14px 8px', background:ORANGE, border:`2px solid #fff`, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:BG, letterSpacing:1, textAlign:'center', boxShadow:`0 0 16px ${ORANGE}8c`}}>✗ MISS</div>
    <div style={{flex:2, padding:'14px 8px', textAlign:'center',
      background: lockable?GREEN:'transparent',
      border:`2px solid ${lockable?'#fff':'rgba(255,255,255,0.18)'}`,
      color: lockable?BG:'rgba(255,255,255,0.3)',
      fontFamily:'"Press Start 2P", monospace', fontSize:11, letterSpacing:1.5,
      boxShadow: lockable?`0 0 18px ${GREEN}aa`:'none',
      opacity: lockable?1:0.6}}>🔒 LOCK IN</div>
    <div style={{flex:1, padding:'14px 8px', border:`2px solid ${CYAN}`, fontFamily:'"Press Start 2P", monospace', fontSize:10, color:CYAN, letterSpacing:1, textAlign:'center'}}>⋯ MENU</div>
  </div>
);

const relPar = (v) => v===0 ? 'E' : v>0 ? `+${v}` : `${v}`;
const relCol = (v) => v<0 ? GREEN : v>0 ? ORANGE : PHOSPHOR;

// ════════════════════════════════════════════════════════════════
// ACTIVE CARD — hole context + LYING + total strokes.
// state: 'start' | 'mid' | 'locked' | 'bogey'
// ════════════════════════════════════════════════════════════════
const GFActiveCard = ({ p }) => {
  const c = p.accent;
  const lying = p.lie;                 // strokes if you stop now (last dart)
  const done = lying != null;
  const term = done ? GF_TERM[lying] : null;
  const locked = p.state==='locked' || p.state==='bogey';
  const frame = locked ? (lying<=PAR?GREEN:RED) : c;
  return (
    <div style={{position:'relative', margin:'16px 16px 0', border:`3px solid ${frame}`,
                 background:`linear-gradient(180deg, ${frame}18 0%, ${frame}05 100%)`,
                 boxShadow:`0 0 20px ${frame}50`, padding:'14px 18px 16px'}}>
      <div style={{position:'absolute', top:-9, left:16, padding:'3px 9px', background:frame, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:9, letterSpacing:1.5, boxShadow:`0 0 8px ${frame}aa`}}>▶ NOW THROWING</div>

      <div style={{display:'flex', alignItems:'center', gap:14, marginTop:3}}>
        <div style={{width:50, height:50, background:BG, border:`3px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, textShadow:`0 0 8px ${c}aa`, flexShrink:0, boxShadow:`0 0 12px ${c}55`}}>{p.handle}</div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:17, color:'#fff', letterSpacing:2, lineHeight:1}}>{p.name.toUpperCase()}</div>
          <div style={{display:'flex', alignItems:'center', gap:10, marginTop:9}}>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:YELLOW, letterSpacing:1, textShadow:`0 0 6px ${YELLOW}88`}}>HOLE {p.hole}</span>
            <span style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.35)'}}>·</span>
            <span style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.65)', letterSpacing:1}}>PAR {PAR}</span>
            <span style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.35)'}}>·</span>
            <div style={{display:'flex', gap:5}}>
              {[0,1,2].map(i=>(
                <div key={i} style={{width:9, height:9, background:i<p.darts?c:'transparent', border:`2px solid ${c}`, boxShadow:i<p.darts?`0 0 6px ${c}aa`:'none'}}></div>
              ))}
            </div>
            <span style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>{p.darts}/3</span>
          </div>
        </div>
        {/* total strokes */}
        <div style={{textAlign:'right', flexShrink:0}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>STROKES</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:40, color:c, lineHeight:1, textShadow:`0 0 14px ${c}aa`, letterSpacing:-1, marginTop:4}}>{p.total}</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:relCol(p.vsPar), letterSpacing:1, marginTop:3}}>{relPar(p.vsPar)} vs par</div>
        </div>
      </div>

      {/* LYING line — the press-your-luck heartbeat */}
      <div style={{marginTop:13, padding:'11px 14px', display:'flex', alignItems:'center', gap:12,
                   background: done?`${term.col}18`:'rgba(255,255,255,0.05)',
                   border:`2px solid ${done?term.col:'rgba(255,255,255,0.14)'}`}}>
        {!done ? (
          <span style={{fontFamily:'"VT323", monospace', fontSize:19, color:'rgba(255,255,255,0.55)', letterSpacing:1}}>▸ TEE OFF — THROW AT THE {p.hole}. LAST DART COUNTS.</span>
        ) : (
          <React.Fragment>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:15, color:'#fff', letterSpacing:1}}>LYING {lying}</span>
            <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:term.col, letterSpacing:1, textShadow:`0 0 6px ${term.col}`}}>{term.term}</span>
            <span style={{flex:1}}/>
            {p.state==='mid'   && <span style={{fontFamily:'"VT323", monospace', fontSize:18, color:YELLOW, letterSpacing:1}}>LOCK IN OR RISK?</span>}
            {p.state==='locked'&& <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:GREEN, letterSpacing:1, textShadow:`0 0 6px ${GREEN}`}}>🔒 LOCKED IN</span>}
            {p.state==='bogey' && <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:RED, letterSpacing:1, textShadow:`0 0 6px ${RED}`}}>HOLE OVER · MISS</span>}
          </React.Fragment>
        )}
      </div>
    </div>
  );
};

// ── mini standings — total strokes + vs par, leader marked ───────
const GFStandings = ({ players }) => {
  const ordered = [...players].sort((a,b)=>a.total-b.total);
  return (
    <div style={{margin:'14px 16px 0', border:`2px solid ${MAGENTA}55`}}>
      <div style={{padding:'7px 12px', background:`${MAGENTA}15`, borderBottom:`2px solid ${MAGENTA}55`, fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.6)', letterSpacing:2}}>LEADERBOARD · LOWEST STROKES</div>
      {ordered.map((p,i)=>(
        <div key={p.handle} style={{display:'grid', gridTemplateColumns:'26px 60px 1fr 58px 48px', alignItems:'center', gap:10, padding:'8px 12px', background: p.active?`${p.accent}12`:'transparent', borderBottom: i<ordered.length-1?`1px solid ${MAGENTA}22`:'none'}}>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:i===0?YELLOW:'rgba(255,255,255,0.4)', textShadow:i===0?`0 0 6px ${YELLOW}88`:'none'}}>{i+1}</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:p.active?p.accent:PHOSPHOR, letterSpacing:1, textShadow:`0 0 6px ${p.active?p.accent:PHOSPHOR}66`}}>{p.active&&'▶'}{p.handle}</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.45)', letterSpacing:1}}>thru {p.thru}</div>
          <div style={{textAlign:'right', fontFamily:'"Press Start 2P", monospace', fontSize:15, color:'#fff'}}>{p.total}</div>
          <div style={{textAlign:'right', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:relCol(p.vsPar)}}>{relPar(p.vsPar)}</div>
        </div>
      ))}
    </div>
  );
};

// ── input — S/D/T cells on the hole's number → stroke value ──────
const GFInput = ({ hole, sudden }) => {
  const cells = [
    { z:`S${hole}`, stroke:3, note:'single' },
    { z:`D${hole}`, stroke:2, note:'double' },
    { z:`T${hole}`, stroke:1, note:'triple' },
  ];
  return (
    <div style={{padding:'16px 16px 0'}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.45)', letterSpacing:2, marginBottom:9, textAlign:'center'}}>
        THROW AT <b style={{color:YELLOW, fontFamily:'"Press Start 2P", monospace', fontSize:11}}>{sudden?'BULL':hole}</b> · MISS = BOGEY (5 STROKES)
      </div>
      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:10}}>
        {cells.map(cel=>{
          const t = GF_TERM[cel.stroke];
          return (
            <div key={cel.z} style={{background:`${t.col}12`, border:`2px solid ${t.col}`, boxShadow:`0 0 12px ${t.col}33`, padding:'15px 0 11px', display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:24, color:t.col, textShadow:`0 0 10px ${t.col}aa`}}>{cel.z}</div>
              <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1}}>{t.term}</div>
              <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.55)', letterSpacing:1}}>{cel.stroke} STROKE{cel.stroke>1?'S':''}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ── scorecard strip — hole-by-hole, current highlighted (inline) ─
const GFScorecardStrip = ({ holeStrokes, hole, holes }) => {
  const shown = holes; // show all holes in the strip
  return (
    <div style={{margin:'16px 16px 0'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:7}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:PHOSPHOR, letterSpacing:1.5}}>YOUR CARD</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:CYAN, letterSpacing:1}}>▸ TAP TO EXPAND</div>
      </div>
      <div style={{display:'grid', gridTemplateColumns:`repeat(${shown}, 1fr)`, gap:3}}>
        {Array.from({length:shown}).map((_,i)=>{
          const h = i+1;
          const st = holeStrokes[i];
          const played = st != null;
          const cur = h===hole;
          const t = played ? GF_TERM[st] : null;
          return (
            <div key={h} style={{textAlign:'center'}}>
              <div style={{fontFamily:'"VT323", monospace', fontSize:11, color:cur?YELLOW:'rgba(255,255,255,0.4)', letterSpacing:0}}>{h}</div>
              <div style={{marginTop:3, height:26, display:'flex', alignItems:'center', justifyContent:'center',
                border:`1.5px solid ${cur?YELLOW:played?t.col+'88':'rgba(255,255,255,0.12)'}`,
                background: cur?`${YELLOW}18`:played?`${t.col}14`:'transparent',
                boxShadow: cur?`0 0 8px ${YELLOW}66`:'none',
                fontFamily:'"Press Start 2P", monospace', fontSize:10,
                color: cur?YELLOW:played?t.col:'rgba(255,255,255,0.25)'}}>
                {played?st:cur?'●':'·'}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ── moment overlay ───────────────────────────────────────────────
const GFOverlay = ({ tint, children }) => (
  <div style={{position:'absolute', inset:0, zIndex:8, display:'flex', alignItems:'center', justifyContent:'center',
               background:`radial-gradient(ellipse at center, ${tint}22 0%, rgba(5,0,14,0.86) 70%)`, backdropFilter:'blur(2px)'}}>
    {children}
  </div>
);

// ════════════════════════════════════════════════════════════════
// COCKPIT — no in-cockpit winner overlay (post-game is the winner surface)
// ════════════════════════════════════════════════════════════════
const GFCockpit = ({ s }) => (
  <GFFrame>
    <GFTopBar hole={s.hole} holes={s.holes} sudden={s.sudden}/>
    <GFActiveCard p={s.active}/>
    <GFStandings players={s.players}/>
    <GFInput hole={s.active.hole} sudden={s.sudden}/>
    <GFScorecardStrip holeStrokes={s.card} hole={s.active.hole} holes={s.holes}/>
    {s.overlay==='ace' && (
      <GFOverlay tint={CYAN}>
        <div style={{textAlign:'center'}}>
          <div style={{fontSize:34, letterSpacing:6, color:CYAN}}>✦ ✦ ✦</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:64, color:CYAN, letterSpacing:3, textShadow:`0 0 28px ${CYAN}, 4px 4px 0 ${MAGENTA}`, marginTop:12, animation:'gfPop 0.5s ease-out'}}>ACE!</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:'#fff', letterSpacing:2, marginTop:18}}>{s.active.name.toUpperCase()} · T{s.active.hole} · 1 STROKE</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:22, color:GREEN, letterSpacing:2, marginTop:8}}>HOLE {s.active.hole} IN ONE THROW</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.4)', letterSpacing:2, marginTop:16}}>TAP TO CONTINUE · AUTO 1s</div>
        </div>
      </GFOverlay>
    )}
    {s.overlay==='sudden' && (
      <GFOverlay tint={RED}>
        <div style={{textAlign:'center'}}>
          <div style={{fontSize:44}}>⛳</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:40, color:RED, letterSpacing:2, textShadow:`0 0 22px ${RED}`, marginTop:12, lineHeight:1.15}}>SUDDEN<br/>DEATH</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:24, color:'#fff', letterSpacing:2, marginTop:14}}>TIED AT {s.active.total} · PLAYOFF ON BULL</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:YELLOW, letterSpacing:1, marginTop:14, textShadow:`0 0 8px ${YELLOW}88`}}>LOWEST STROKE WINS · 19 → 20 → BULL</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.4)', letterSpacing:2, marginTop:16}}>TAP TO CONTINUE · AUTO 1s</div>
        </div>
      </GFOverlay>
    )}
    <GFActionBar lockable={s.lockable}/>
  </GFFrame>
);

// ════════════════════════════════════════════════════════════════
// FULL SCORECARD SHEET — the expandable golf card, all holes×players
// ════════════════════════════════════════════════════════════════
const GFScoreSheet = ({ s }) => {
  const holes = s.holes;
  const rows = s.players;
  return (
    <GFFrame>
      <GFTopBar hole={s.hole} holes={holes}/>
      <div style={{padding:'18px 16px 0', display:'flex', alignItems:'center', justifyContent:'space-between'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:CYAN, letterSpacing:2, textShadow:`0 0 8px ${CYAN}88`}}>SCORECARD</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>PAR {PAR} EACH · ✕ CLOSE</div>
      </div>
      <div style={{margin:'16px 12px', border:`2px solid ${MAGENTA}55`, overflow:'hidden'}}>
        {/* header row: hole numbers */}
        <div style={{display:'grid', gridTemplateColumns:`74px repeat(${holes}, 1fr) 54px`, background:`${MAGENTA}18`, borderBottom:`2px solid ${MAGENTA}55`}}>
          <div style={{padding:'9px 8px', fontFamily:'"Press Start 2P", monospace', fontSize:9, color:'rgba(255,255,255,0.6)', letterSpacing:1}}>HOLE</div>
          {Array.from({length:holes}).map((_,i)=>(
            <div key={i} style={{padding:'9px 0', textAlign:'center', fontFamily:'"VT323", monospace', fontSize:15, color: (i+1)===s.hole?YELLOW:'rgba(255,255,255,0.55)', letterSpacing:0, borderLeft:`1px solid ${MAGENTA}22`}}>{i+1}</div>
          ))}
          <div style={{padding:'9px 0', textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:9, color:YELLOW, letterSpacing:0, borderLeft:`1px solid ${MAGENTA}44`}}>TOT</div>
        </div>
        {/* par row */}
        <div style={{display:'grid', gridTemplateColumns:`74px repeat(${holes}, 1fr) 54px`, background:'rgba(255,255,255,0.02)', borderBottom:`1px solid ${MAGENTA}22`}}>
          <div style={{padding:'7px 8px', fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.45)', letterSpacing:1}}>PAR</div>
          {Array.from({length:holes}).map((_,i)=>(
            <div key={i} style={{padding:'7px 0', textAlign:'center', fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.35)', borderLeft:`1px solid ${MAGENTA}14`}}>{PAR}</div>
          ))}
          <div style={{padding:'7px 0', textAlign:'center', fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.4)', borderLeft:`1px solid ${MAGENTA}44`}}>{PAR*holes}</div>
        </div>
        {/* player rows */}
        {rows.map((p,ri)=>(
          <div key={p.handle} style={{display:'grid', gridTemplateColumns:`74px repeat(${holes}, 1fr) 54px`, background: p.active?`${p.accent}10`:'transparent', borderBottom: ri<rows.length-1?`1px solid ${MAGENTA}18`:'none'}}>
            <div style={{padding:'9px 8px', fontFamily:'"Press Start 2P", monospace', fontSize:10, color:p.active?p.accent:PHOSPHOR, letterSpacing:1, display:'flex', alignItems:'center', gap:4}}>{p.active&&<span>▶</span>}{p.handle}</div>
            {Array.from({length:holes}).map((_,i)=>{
              const st = p.card[i];
              const played = st!=null;
              const t = played?GF_TERM[st]:null;
              const cur = (i+1)===s.hole && p.active;
              return (
                <div key={i} style={{padding:'9px 0', textAlign:'center', borderLeft:`1px solid ${MAGENTA}14`,
                  background: cur?`${YELLOW}18`:'transparent',
                  fontFamily:'"Press Start 2P", monospace', fontSize:11,
                  color: played?t.col:cur?YELLOW:'rgba(255,255,255,0.18)',
                  textShadow: played&&st===1?`0 0 6px ${t.col}`:'none'}}>{played?st:cur?'●':'·'}</div>
              );
            })}
            <div style={{padding:'9px 0', textAlign:'center', borderLeft:`1px solid ${MAGENTA}44`, fontFamily:'"Press Start 2P", monospace', fontSize:12, color:'#fff'}}>{p.total}</div>
          </div>
        ))}
      </div>
      {/* legend */}
      <div style={{display:'flex', justifyContent:'center', gap:16, flexWrap:'wrap', padding:'2px 16px'}}>
        {[[1,'ACE'],[2,'BIRDIE'],[3,'PAR'],[5,'BOGEY']].map(([st,lbl])=>{
          const t=GF_TERM[st];
          return (
            <div key={lbl} style={{display:'flex', alignItems:'center', gap:6}}>
              <div style={{width:16, height:16, border:`1.5px solid ${t.col}`, background:`${t.col}22`, fontFamily:'"Press Start 2P", monospace', fontSize:8, color:t.col, display:'flex', alignItems:'center', justifyContent:'center'}}>{st}</div>
              <span style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.6)', letterSpacing:1}}>{lbl}</span>
            </div>
          );
        })}
      </div>
      <GFActionBar lockable={false}/>
    </GFFrame>
  );
};

// ════════════════════════════════════════════════════════════════
// SCREEN SHELL — dark arcade wrapper for home / setup / post-game
// ════════════════════════════════════════════════════════════════
const GFScreen = ({ children }) => (
  <div style={{width:GF_W, height:GF_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', position:'relative', overflow:'hidden', display:'flex', flexDirection:'column'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:gfScan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {children}
  </div>
);

// ── HOME — 3×3 mode grid; Golf lit (NEW), WILDCARD dimmed soon ────
const GF_TILES = [
  { name:'X01', emoji:'🎯' }, { name:'CRICKET', emoji:'🦗' }, { name:'SHANGHAI', emoji:'🏙️' },
  { name:'GOTCHA', emoji:'💀' }, { name:'1UP', emoji:'🕹️' }, { name:'HALVE IT', emoji:'✂️' },
  { name:'ATC', emoji:'🕐' }, { name:'GOLF', emoji:'⛳', hero:true }, { name:'WILDCARD', emoji:'🃏', soon:true },
];
const GFHome = () => (
  <GFScreen>
    <div style={{padding:'24px 24px 12px', textAlign:'center', position:'relative', zIndex:6}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:26, color:MAGENTA, letterSpacing:3, textShadow:`0 0 12px ${MAGENTA}, 4px 4px 0 ${CYAN}55`}}>DOSSEDART</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.5)', letterSpacing:4, marginTop:8}}>SELECT GAME MODE</div>
    </div>
    <div style={{flex:1, padding:'10px 24px 26px', display:'grid', gridTemplateColumns:'repeat(3,1fr)', gridTemplateRows:'repeat(3,1fr)', gap:16, position:'relative', zIndex:6}}>
      {GF_TILES.map(t=>{
        const c = t.hero ? GOLF : CYAN;
        return (
          <div key={t.name} style={{position:'relative', border:`3px solid ${t.soon?'rgba(255,255,255,0.14)':c}`,
            background: t.hero?`linear-gradient(180deg, ${GOLF}26, ${GOLF}08)`:'rgba(255,255,255,0.03)',
            boxShadow: t.soon?'none':`0 0 18px ${c}55`, opacity: t.soon?0.5:1,
            display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:10}}>
            <div style={{fontSize:38, filter:t.soon?'grayscale(1)':'none'}}>{t.emoji}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color: t.soon?'rgba(255,255,255,0.5)':'#fff', letterSpacing:1, textShadow: t.soon?'none':`0 0 8px ${c}88`, textAlign:'center'}}>{t.name}</div>
            {t.hero && <div style={{position:'absolute', top:-9, right:10, padding:'2px 7px', background:GOLF, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:8, letterSpacing:1, boxShadow:`0 0 8px ${GOLF}`}}>NEW</div>}
            {t.soon && <div style={{position:'absolute', bottom:9, fontFamily:'"Press Start 2P", monospace', fontSize:8, color:'rgba(255,255,255,0.4)', letterSpacing:1}}>SOON</div>}
          </div>
        );
      })}
    </div>
  </GFScreen>
);

// ── SETUP — reused player list + Golf course selector (9 / 18) ───
const GFChip = ({ label, sub, on, accent=GOLF }) => (
  <div style={{flex:1, minWidth:0, padding:'14px 10px', textAlign:'center', border:`2px solid ${on?accent:'rgba(255,255,255,0.16)'}`,
    background:on?`${accent}1e`:'transparent', boxShadow:on?`0 0 14px ${accent}55`:'none'}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:on?'#fff':'rgba(255,255,255,0.6)', letterSpacing:1, textShadow:on?`0 0 6px ${accent}`:'none'}}>{label}</div>
    {sub && <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:on?accent:'rgba(255,255,255,0.4)', letterSpacing:1, marginTop:6}}>{sub}</div>}
  </div>
);
const GF_SETUP_PLAYERS = [['Jonas','JON',CYAN],['Kari','KAR',MAGENTA],['Per','PER',GREEN],['Mia','MIA',YELLOW]];
const GFSetup = () => (
  <GFScreen>
    <div style={{padding:'16px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ BACK</div>
      <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:GOLF, letterSpacing:2, textShadow:`0 0 8px ${GOLF}88`}}>⛳ GOLF · SETUP</div>
      <div style={{width:40}}></div>
    </div>
    <div style={{flex:1, padding:'20px 24px', overflow:'hidden', position:'relative', zIndex:6, display:'flex', flexDirection:'column'}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'rgba(255,255,255,0.5)', letterSpacing:2, marginBottom:10}}>PLAYERS · 4</div>
      <div style={{display:'flex', flexDirection:'column', gap:8}}>
        {GF_SETUP_PLAYERS.map(([n,h,c])=>(
          <div key={h} style={{display:'flex', alignItems:'center', gap:12, padding:'10px 12px', border:`2px solid ${c}66`, background:`${c}0d`}}>
            <div style={{width:36, height:36, background:BG, border:`2px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:10, color:c}}>{h}</div>
            <div style={{flex:1, fontFamily:'"Press Start 2P", monospace', fontSize:12, color:'#fff', letterSpacing:1}}>{n.toUpperCase()}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.35)'}}>✕</div>
          </div>
        ))}
      </div>
      <div style={{marginTop:22}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:GOLF, letterSpacing:2, marginBottom:10, textShadow:`0 0 6px ${GOLF}88`}}>COURSE</div>
        <div style={{display:'flex', gap:10}}>
          <GFChip label="9 HOLES" sub="front nine · 1–9" on={false}/>
          <GFChip label="18 HOLES" sub="full round · 1–18" on={true}/>
        </div>
      </div>
      <div style={{marginTop:20, padding:'12px 14px', border:'2px solid rgba(255,255,255,0.12)', background:'rgba(255,255,255,0.02)'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'rgba(255,255,255,0.6)', letterSpacing:1, lineHeight:1.5}}>
          <b style={{color:GOLF, fontFamily:'"Press Start 2P", monospace', fontSize:9}}>RULES</b>  &nbsp;Play each number in order · last dart counts · <b style={{color:'#fff'}}>T=1 · D=2 · S=3 · miss=5</b> · LOCK IN or risk · lowest total wins.
        </div>
      </div>
      <div style={{marginTop:'auto', padding:'16px', background:`linear-gradient(90deg, ${GOLF}, ${CYAN})`, color:BG, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:14, letterSpacing:2, boxShadow:`0 0 22px ${GOLF}88`}}>▶ TEE OFF</div>
    </div>
  </GFScreen>
);

// ── POST-GAME — placements by total strokes ascending + stat rows ─
const GFPostGame = ({ places, stats }) => (
  <GFScreen>
    <div style={{padding:'16px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, textAlign:'center', position:'relative', zIndex:6}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:YELLOW, letterSpacing:2, textShadow:`0 0 8px ${YELLOW}88`}}>⛳ GOLF · RESULTS</div>
    </div>
    <div style={{flex:1, padding:'16px 24px 20px', overflow:'hidden', position:'relative', zIndex:6, display:'flex', flexDirection:'column'}}>
      <div style={{textAlign:'center', marginBottom:8}}>
        <div style={{fontSize:22, letterSpacing:6, color:YELLOW}}>★ ★ ★</div>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:24, color:YELLOW, letterSpacing:2, textShadow:`0 0 20px ${YELLOW}, 4px 4px 0 ${MAGENTA}`, marginTop:8}}>{places[0].name} WINS</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:GOLF, letterSpacing:2, marginTop:6}}>CLUBHOUSE LEADER · {places[0].total} STROKES · {relPar(places[0].vsPar)}</div>
      </div>
      <div style={{display:'flex', flexDirection:'column', gap:7}}>
        {places.map((p,i)=>(
          <div key={p.handle} style={{display:'flex', alignItems:'center', gap:12, padding:'10px 13px', border:`2px solid ${p.metal}`, background:`${p.accent}0d`}}>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:p.metal, width:38, textShadow:`0 0 8px ${p.metal}88`}}>{p.place}</div>
            <div style={{width:34, height:34, background:BG, border:`2px solid ${p.accent}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:10, color:p.accent}}>{p.handle}</div>
            <div style={{flex:1, fontFamily:'"Press Start 2P", monospace', fontSize:12, color:'#fff', letterSpacing:1}}>{p.name}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:15, color:'#fff'}}>{p.total}</div>
            <div style={{width:46, textAlign:'right', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:relCol(p.vsPar)}}>{relPar(p.vsPar)}</div>
          </div>
        ))}
      </div>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', margin:'20px 0 6px'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:GOLF, letterSpacing:2, textShadow:`0 0 6px ${GOLF}88`}}>MATCH STATS</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:CYAN, letterSpacing:1}}>▸ FULL SCORECARD</div>
      </div>
      <div style={{display:'flex', flexDirection:'column'}}>
        {stats.map(([label,val,who])=>(
          <div key={label} style={{display:'flex', alignItems:'center', gap:12, padding:'10px 4px', borderBottom:'1px solid rgba(255,255,255,0.08)'}}>
            <div style={{flex:1, fontFamily:'"VT323", monospace', fontSize:19, color:'rgba(255,255,255,0.7)', letterSpacing:1}}>{label}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:'#fff'}}>{val}</div>
            <div style={{width:82, textAlign:'right', fontFamily:'"VT323", monospace', fontSize:15, color: who==='total'?'rgba(255,255,255,0.4)':YELLOW, letterSpacing:1}}>{who}</div>
          </div>
        ))}
      </div>
      <div style={{marginTop:'auto', display:'flex', gap:10}}>
        <div style={{flex:1, padding:'14px', border:`2px solid ${CYAN}`, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1}}>↶ UNDO</div>
        <div style={{flex:2, padding:'14px', background:ORANGE, color:BG, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, letterSpacing:1, boxShadow:`0 0 16px ${ORANGE}88`}}>▶ REMATCH</div>
      </div>
    </div>
  </GFScreen>
);

// ── scenarios ────────────────────────────────────────────────────
// card = 18 strokes-per-hole array (null = not played). vsPar/total derived.
const mkCard = (strokes) => { const c = Array(18).fill(null); strokes.forEach((s,i)=>c[i]=s); return c; };
const sumCard = (c) => c.reduce((a,v)=>a+(v||0),0);
const thruCard = (c) => c.filter(v=>v!=null).length;
const vsParCard = (c) => sumCard(c) - PAR*thruCard(c);

const gfPlayer = (name, handle, accent, strokes, extra={}) => {
  const card = mkCard(strokes);
  return { name, handle, accent, card, total:sumCard(card), thru:thruCard(card), vsPar:vsParCard(card), ...extra };
};

// six holes played by everyone; hole 7 in progress (cockpit states)
const CARDS = {
  jon: [3,2,3,1,3,2],
  kari:[3,3,2,3,3,3],
  per: [2,3,3,3,2,4],
  mia: [3,3,4,3,3,3],
};
const mkPlayers = (activeKey, holeCtx) => {
  const base = [
    gfPlayer('Jonas','JON',CYAN, CARDS.jon),
    gfPlayer('Kari','KAR',MAGENTA, CARDS.kari),
    gfPlayer('Per','PER',GREEN, CARDS.per),
    gfPlayer('Mia','MIA',YELLOW, CARDS.mia),
  ];
  return base.map(p=>({ ...p, active: p.handle===activeKey }));
};

const activeFrom = (players, hole, darts, lie, state) => {
  const p = players.find(x=>x.active);
  return { ...p, hole, darts, lie, state };
};

function makeState(activeKey, hole, darts, lie, state, opts={}){
  const players = mkPlayers(activeKey, hole);
  const active = activeFrom(players, hole, darts, lie, state);
  return { hole, holes:18, players, active, card:active.card, lockable: opts.lockable ?? (darts>=1 && state!=='start'), ...opts };
}

const GF_STATES = {
  start:   makeState('JON', 7, 0, null, 'start', { lockable:false }),
  mid:     makeState('JON', 7, 2, 2,   'mid',   { lockable:true }),
  ace:     makeState('JON', 7, 1, 1,   'mid',   { lockable:true, overlay:'ace' }),
  locked:  makeState('JON', 7, 2, 2,   'locked',{ lockable:false }),
  bogey:   makeState('PER', 7, 3, 5,   'bogey', { lockable:false }),
  between: makeState('KAR', 8, 0, null,'start', { lockable:false, between:true }),
  sudden:  (()=>{ const st = makeState('JON', 18, 0, null, 'start', { lockable:false, sudden:true, overlay:'sudden' }); st.active.total=54; st.active.vsPar=0; return st; })(),
};

// full scorecard sheet uses the mid-game state
const GF_SHEET = (()=>{ const players = mkPlayers('JON', 7); return { hole:7, holes:18, players }; })();

// ── post-game — a completed 18-hole round ────────────────────────
const GF_FINAL_CARDS = {
  JON: [3,3,2,3,3,3, 3,1,3,3,2,3, 3,3,2,3,3,2], // 48  aces1 birdies4 bogeys0
  KAR: [3,3,3,3,2,3, 3,3,3,2,3,3, 5,3,3,2,3,3], // 53  bogeys1
  PER: [3,3,3,3,3,3, 3,3,5,3,3,3, 3,3,3,2,3,5], // 57  bogeys2
  MIA: [3,3,5,3,3,3, 3,3,3,3,5,3, 3,3,3,3,3,5], // 60  bogeys3
};
const GF_META = {
  JON:['Jonas',CYAN], KAR:['Kari',MAGENTA], PER:['Per',GREEN], MIA:['Mia',YELLOW],
};
const GF_MEDAL = [YELLOW,'#C9D2DA','#D08A4A','rgba(255,255,255,0.3)'];
const GF_PLACES = (()=>{
  const rows = Object.keys(GF_FINAL_CARDS).map(h=>{
    const [name,accent]=GF_META[h]; const c=mkCard(GF_FINAL_CARDS[h]);
    return { handle:h, name:name.toUpperCase(), accent, total:sumCard(c), vsPar:vsParCard(c), card:c };
  }).sort((a,b)=>a.total-b.total);
  const labels=['1ST','2ND','3RD','4TH'];
  return rows.map((r,i)=>({ ...r, place:labels[i], metal:GF_MEDAL[i] }));
})();
const cnt = (h,v)=>mkCard(GF_FINAL_CARDS[h]).filter(x=>x===v).length;
const GF_STATS = [
  ['TOTAL STROKES', String(GF_PLACES[0].total), 'JONAS'],
  ['VS PAR', relPar(GF_PLACES[0].vsPar), 'JONAS'],
  ['ACES (T)', String(Object.keys(GF_FINAL_CARDS).reduce((a,h)=>a+cnt(h,1),0)), 'total'],
  ['BOGEYS', String(Object.keys(GF_FINAL_CARDS).reduce((a,h)=>a+cnt(h,5),0)), 'total'],
  ['LOCK-INS', '23', 'total'],
  ['BEST HOLE', 'H8 · ACE', 'JONAS'],
];
const GF_SHEET_FINAL = (()=>{
  const players = GF_PLACES.map(p=>({ ...p, thru:18 }));
  return { hole:19, holes:18, players };
})();

// ════════════════════════════════════════════════════════════════
// SPEC CARD
// ════════════════════════════════════════════════════════════════
const GFSpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    {hex && <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}/>}
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);
const GFSpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1300, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:13, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Golf · cockpit · fasit</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:26, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Hull, LYING og LOCK IN — press-your-luck</div>
    </div>
    <div style={{padding:'11px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a4a36', marginBottom:4}}>Uendret (gjenbruk)</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#2a4a36', lineHeight:1.5}}>Frame + scanlines, TopBar og ActionBar-chrome er urørt. Input er ATCs <b>S/D/T-soneceller</b> på hullets tall (ikke fullt brett). Leaderboard, PlayerSetupScreen, post_game_screen og 3×3 home-grid følger eksisterende mønster.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Nye elementer</div>
      <GFSpecRow zone="HOLE n · PAR 3 + LYING n (press-your-luck)" val="siste dart teller" hex={YELLOW}/>
      <GFSpecRow zone="LOCK IN — FJERDE ActionBar-knapp" val="kun Golf har den" hex={GREEN}/>
      <GFSpecRow zone="Scorecard — hull-for-hull (strip + sheet)" val="inline + expand" hex={CYAN}/>
      <GFSpecRow zone="Setup — COURSE 9 / 18 (default 18)" val="chips" hex={GOLF}/>
      <GFSpecRow zone="ACE-feiring / sudden death" val="moment-overlays" hex={MAGENTA}/>
    </div>
    <div style={{padding:'11px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Slag-verdier (fasit)</div>
      <div style={{display:'flex', gap:14, flexWrap:'wrap', marginTop:4}}>
        {[['T',1,'ACE',CYAN],['D',2,'BIRDIE',GREEN],['S',3,'PAR',PHOSPHOR],['MISS',5,'BOGEY',RED]].map(([z,st,lbl,col])=>(
          <div key={lbl} style={{display:'flex', alignItems:'center', gap:6}}>
            <div style={{width:15, height:15, background:col, border:'1px solid rgba(0,0,0,0.2)'}}/>
            <span style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11.5, color:'#2a251f'}}><b>{z}</b> = {st} · {lbl}</span>
          </div>
        ))}
      </div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>8 states (spec §4.3)</div>
      {[
        ['1 · Hole start','Ingen dart kastet, LOCK IN disabled (dimmet). «TEE OFF».'],
        ['2 · Mid-hole decision','LYING n vist, LOCK IN grønn/aktiv — signaturøyeblikket «LOCK IN OR RISK?».'],
        ['3 · ACE','Triple = 1 slag → ACE!-overlay (cyan). Tap/1s auto-dismiss.'],
        ['4 · Locked in','Slag beholdt, hull ferdig — grønn ramme, 🔒 LOCKED IN.'],
        ['5 · Bogey','Hull ender på bom → 5 slag, rød ramme, «HOLE OVER · MISS».'],
        ['6 · Between holes','Alle ferdige med hull N → neste tee, oppdatert leaderboard.'],
        ['7 · Sudden death','Uavgjort 1.plass → playoff 19→20→Bull, kun ledere.'],
        ['8 · Winner = POST-GAME','Ingen in-cockpit winner-overlay (1UP QA-lekse). Post-game er eneste winner-flate: podium + stat-rader.'],
      ].map(([t,b])=>(
        <div key={t} style={{padding:'6px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, fontWeight:700, color:'#2a251f'}}>{t}</div>
          <div style={{fontFamily:'"Inter", sans-serif', fontSize:11.5, lineHeight:1.4, color:'#5a544a', marginTop:2}}>{b}</div>
        </div>
      ))}
    </div>
    <div style={{padding:'11px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.5, color:'#2a4a36'}}>
        <b>Brand-aksent:</b> eksisterende <b>green #3DFF8E</b>-token (brief §4 Golf accent) — <b>ingen nytt token</b>. Brukt i TopBar-tittel, home-tile «NEW»-glød, setup-labels + TEE OFF-CTA, LOCK IN/SAFE. Rød/oransje = bogey/fare, cyan = ACE, gul = highlight/winner-label.
      </div>
    </div>
    <div style={{marginTop:'auto', padding:'11px 14px', background:'#fbe9d8', border:'1px solid rgba(201,100,66,0.35)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.5, color:'#5a442f'}}>
        <b>LOCK IN-tilstand:</b> disabled før dart 1, aktiv (grønn) etter dart 1 og 2, irrelevant etter dart 3 (hull auto-ender). Scorecard-strip er inline; full sheet er egen expand. Placements = total strokes stigende; sudden death avgjør kun 1.plass. Alle UI-strenger engelske (norsk-guard).
      </div>
    </div>
  </div>
);

// keyframes
if (typeof document !== 'undefined' && !document.getElementById('golf-kf')) {
  const st = document.createElement('style');
  st.id = 'golf-kf';
  st.textContent = `@keyframes gfPop { 0%{transform:scale(0.5) rotate(-6deg);opacity:0} 55%{transform:scale(1.15) rotate(3deg);opacity:1} 100%{transform:scale(1) rotate(0)} }
    @media (prefers-reduced-motion: reduce){ [style*="gfPop"]{animation:none!important} }`;
  document.head.appendChild(st);
}

// ── Canvas ───────────────────────────────────────────────────────
const GolfCockpit = () => (
  <React.Fragment>
    <DCSection id="gf-home" title="Home — 3×3 mode grid"
      subtitle="Golf-tile i tent/shipped-variant (grønn «NEW»-glød, ⛳). WILDCARD vist som dimmet coming-soon-tile (bygges sist). Tile-chrome + grid er gjenbruk; kun modus-brandingen er ny.">
      <DCArtboard id="gf-home-1" label="Home · Golf lit" width={GF_W} height={GF_H}><GFHome/></DCArtboard>
    </DCSection>

    <DCSection id="gf-setup" title="Setup — Golf-alternativer"
      subtitle="Gjenbruker PlayerSetupScreen + Golf sin ene nye kontroll: COURSE-velger (9 / 18 hull, default 18). Rules-oppsummering + TEE OFF-CTA.">
      <DCArtboard id="gf-setup-1" label="Setup · course 9/18" width={GF_W} height={GF_H}><GFSetup/></DCArtboard>
    </DCSection>

    <DCSection id="gf-cockpit" title="Golf cockpit — hull, LYING og LOCK IN"
      subtitle="Samme cockpit-chrome (Frame, TopBar, ActionBar) og ATCs S/D/T-soneinput. Golf spiller tallene 1–18 som hull; siste dart teller, så hvert hull er press-your-luck: LOCK IN slagene dine eller risiker én til. Slag: T=1 (ACE) · D=2 (BIRDIE) · S=3 (PAR) · bom=5 (BOGEY). Det NYE: hull-kontekst + LYING, LOCK IN som fjerde ActionBar-knapp, scorecard-strip, ACE-feiring og sudden death. Winner vises KUN i post-game (ingen in-cockpit overlay).">
      <DCArtboard id="gf-1" label="1 · Hole start (LOCK IN disabled)" width={GF_W} height={GF_H}><GFCockpit s={GF_STATES.start}/></DCArtboard>
      <DCArtboard id="gf-2" label="2 · Mid-hole decision ← signatur" width={GF_W} height={GF_H}><GFCockpit s={GF_STATES.mid}/></DCArtboard>
      <DCArtboard id="gf-3" label="3 · ACE (triple = 1 stroke)" width={GF_W} height={GF_H}><GFCockpit s={GF_STATES.ace}/></DCArtboard>
      <DCArtboard id="gf-4" label="4 · Locked in" width={GF_W} height={GF_H}><GFCockpit s={GF_STATES.locked}/></DCArtboard>
      <DCArtboard id="gf-5" label="5 · Bogey (miss = 5)" width={GF_W} height={GF_H}><GFCockpit s={GF_STATES.bogey}/></DCArtboard>
      <DCArtboard id="gf-6" label="6 · Between holes / next tee" width={GF_W} height={GF_H}><GFCockpit s={GF_STATES.between}/></DCArtboard>
      <DCArtboard id="gf-7" label="7 · Sudden death" width={GF_W} height={GF_H}><GFCockpit s={GF_STATES.sudden}/></DCArtboard>
    </DCSection>

    <DCSection id="gf-postgame" title="Post-game — placements + stats (state 8 · winner)"
      subtitle="Eneste winner-flate. Gjenbruker post_game_screen: placements etter total strokes stigende (lavest vinner), mode-spesifikke stat-rader (total strokes, vs par, aces, bogeys, lock-ins, best hole) og lenke til full scorecard.">
      <DCArtboard id="gf-post-1" label="Post-game · results" width={GF_W} height={GF_H}><GFPostGame places={GF_PLACES} stats={GF_STATS}/></DCArtboard>
    </DCSection>

    <DCSection id="gf-card" title="Golf — scorecard (full sheet)"
      subtitle="Den utvidbare golf-cardet: hull × spillere, par-rad, totaler og fargelegging (ACE/BIRDIE/PAR/BOGEY). Nås fra cockpitens «TAP TO EXPAND»-strip og fra post-game «FULL SCORECARD».">
      <DCArtboard id="gf-sheet" label="Scorecard · mid-game (hull 7)" width={GF_W} height={GF_H}><GFScoreSheet s={GF_SHEET}/></DCArtboard>
      <DCArtboard id="gf-sheet-final" label="Scorecard · finished round" width={GF_W} height={GF_H}><GFScoreSheet s={GF_SHEET_FINAL}/></DCArtboard>
    </DCSection>

    <DCSection id="gf-spec" title="Golf — fasit"
      subtitle="Chrome + input er gjenbruk. Ny designinnsats: hull-kontekst/LYING, LOCK IN-knappen, scorecard, setup (9/18), post-game og de nye statene. Brand = eksisterende green-token (intet nytt token).">
      <DCArtboard id="gf-spec-card" label="Spec · Golf" width={680} height={1300}><GFSpecCard/></DCArtboard>
    </DCSection>
  </React.Fragment>
);
window.GolfCockpit = GolfCockpit;
