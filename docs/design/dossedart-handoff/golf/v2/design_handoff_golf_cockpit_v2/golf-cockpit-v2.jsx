// DOSSEDART — Golf cockpit v2 · tablet-QA feedback round (2026-07-20)
// ───────────────────────────────────────────────────────────────
// Pure cockpit-LAYOUT round. Rules v2 are pinned (golf-design §2 +
// RULES-DELTA): NO LOCK IN (standard 3-action bar), NO ACE overlay,
// NO winner overlay. This file only re-lays-out the ONE Golf cockpit.
//
// Design brief for v2, from the Galaxy Tab QA pass:
//   1. Golf's input is only THREE cells — there is no dartboard eating
//      the middle. Use the freed space; stop distributing it like X01.
//   2. Make "what do I throw at" answerable from the oche → a HERO
//      target block: hole number huge + PAR + the LYING line.
//   3. Bring the standalone leaderboard BACK, full-width and bigger.
//   4. The 1–18 strip was unreadable → a WINDOWED strip (bigger cells,
//      holes around the current one) + a prominent SCORECARD affordance.
//
// North star (stakeholder note): only the 3 S/D/T cells REGISTER score.
// Everything else INFORMS. So the input is the one loud, glowing,
// obviously-tappable console; every info surface is a calm flat readout.

const V2_W = 820, V2_H = 1180;

const YELLOW='#FFD200', MAGENTA='#FF00AA', CYAN='#00E5FF', GREEN='#3DFF8E',
      RED='#FF3050', ORANGE='#FF7A00', BG='#0a0014', SURFACE='#150127',
      PHOSPHOR='#D9D2C2';
const GOLF = GREEN;                 // Golf brand = existing green token
const PAR = 3;
const INK = 'rgba(255,255,255,';    // muted info ink base

// stroke → golf term + colour, derived from vs-par of the hole
// (ACE cyan · BIRDIE green · PAR phosphor · BOGEY orange · DBL/TRPL red)
const termFor = (strokes) => {
  if (strokes === 1) return { term:'ACE',          col:CYAN };
  const v = strokes - PAR;
  if (v <= -1)        return { term:'BIRDIE',       col:GREEN };
  if (v === 0)        return { term:'PAR',          col:PHOSPHOR };
  if (v === 1)        return { term:'BOGEY',        col:ORANGE };
  if (v === 2)        return { term:'DOUBLE BOGEY', col:RED };
  return                     { term:'TRIPLE BOGEY', col:RED };
};
const relPar = (v) => v===0 ? 'E' : v>0 ? `+${v}` : `${v}`;
const relCol = (v) => v<0 ? GREEN : v>0 ? ORANGE : PHOSPHOR;

const PS = '"Press Start 2P", monospace';   // headings / numbers / labels
const VT = '"VT323", monospace';             // secondary readout text

// ── shell chrome — CrtFrame + scanlines (reused verbatim) ────────
const v2Scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const V2Frame = ({ children }) => (
  <div style={{width:V2_W, height:V2_H, background:BG, color:'#fff', fontFamily:PS, display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:v2Scan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 52%, rgba(0,0,0,0.62) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {children}
  </div>
);
const V2TopBar = ({ hole, holes, playoff }) => (
  <div style={{padding:'15px 22px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:6}}>
    <div style={{fontFamily:VT, fontSize:19, color:CYAN, letterSpacing:2}}>◀ EXIT</div>
    <div style={{flex:1, textAlign:'center', fontFamily:PS, fontSize:13, color:GOLF, letterSpacing:2, textShadow:`0 0 8px ${GOLF}88`}}>⛳ GOLF</div>
    <div style={{fontFamily:playoff?PS:VT, fontSize:playoff?12:17, color:playoff?RED:INK+'0.55)', letterSpacing:2, textShadow:playoff?`0 0 8px ${RED}88`:'none'}}>{playoff?'PLAYOFF':`HOLE ${hole}/${holes}`}</div>
  </div>
);
// standard 3-action ActionBar (no LOCK IN in v2)
const V2ActionBar = () => (
  <div style={{position:'absolute', left:0, right:0, bottom:0, padding:'13px 16px 17px', background:'#000', borderTop:`2px solid ${YELLOW}`, display:'flex', gap:12, zIndex:6}}>
    <div style={{flex:1, padding:'16px 8px', border:`2px solid ${MAGENTA}`, fontFamily:PS, fontSize:12, color:'#fff', letterSpacing:1, textAlign:'center'}}>↶ UNDO</div>
    <div style={{flex:1, padding:'16px 8px', border:`2px solid ${CYAN}`, fontFamily:PS, fontSize:12, color:CYAN, letterSpacing:1, textAlign:'center'}}>✗ MISS</div>
    <div style={{flex:1, padding:'16px 8px', border:`2px solid ${INK}0.35)`, fontFamily:PS, fontSize:12, color:INK+'0.7)', letterSpacing:1, textAlign:'center'}}>⋯ MENU</div>
  </div>
);

// ════════════════════════════════════════════════════════════════
// HERO TARGET — the "what do I throw at + what's happening" readout.
// Info surface: calm frame, but the HOLE NUMBER is the one big glowing
// element (the aim signal, legible from the oche). Fixes QA #1 + #2.
// mode: 'teeoff' | 'mid' | 'result'
// ════════════════════════════════════════════════════════════════
const V2Hero = ({ p, hole, darts, lie, mode, target, playoff }) => {
  const done = lie != null;
  const t = done ? termFor(lie) : null;
  const isResult = mode === 'result';
  const frame = isResult ? t.col : (INK+'0.16)');
  const aim = target != null ? target : hole;
  const left = 3 - darts;
  return (
    <div style={{position:'relative', margin:'14px 16px 0', border:`2px solid ${frame}`, background:isResult?`linear-gradient(180deg, ${t.col}1e, ${t.col}06)`:'rgba(255,255,255,0.02)', boxShadow:isResult?`0 0 26px ${t.col}55`:'none', padding:'16px 20px 18px'}}>
      <div style={{position:'absolute', top:-9, left:16, padding:'3px 10px', background:isResult?t.col:p.accent, color:BG, fontFamily:PS, fontSize:9, letterSpacing:1.5, boxShadow:`0 0 8px ${(isResult?t.col:p.accent)}aa`}}>{isResult?'▣ HOLE RESULT':'▶ NOW THROWING'}</div>

      {/* identity + running total */}
      <div style={{display:'flex', alignItems:'center', gap:12, marginTop:2}}>
        <div style={{width:42, height:42, background:BG, border:`2px solid ${p.accent}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:PS, fontSize:11, color:p.accent, flexShrink:0}}>{p.handle}</div>
        <div style={{flex:1, fontFamily:PS, fontSize:20, color:'#fff', letterSpacing:2}}>{p.name.toUpperCase()}</div>
        <div style={{textAlign:'right'}}>
          <div style={{fontFamily:PS, fontSize:8, color:INK+'0.45)', letterSpacing:1.5}}>TOTAL</div>
          <div style={{fontFamily:PS, fontSize:22, color:'#fff', lineHeight:1, marginTop:5}}>{p.total} <span style={{fontSize:13, color:relCol(p.vsPar)}}>{relPar(p.vsPar)}</span></div>
        </div>
      </div>

      {/* the AIM — giant hole number */}
      <div style={{display:'flex', alignItems:'center', gap:26, marginTop:12}}>
        <div style={{flexShrink:0, textAlign:'center'}}>
          <div style={{fontFamily:PS, fontSize:11, color:INK+'0.5)', letterSpacing:3, marginBottom:2}}>{playoff?'PLAYOFF':'HOLE'}</div>
          <div style={{fontFamily:PS, fontSize:aim==='BULL'?86:130, color:GOLF, lineHeight:0.82, textShadow:`0 0 30px ${GOLF}bb, 5px 5px 0 rgba(0,0,0,0.55)`, letterSpacing:aim==='BULL'?0:-4}}>{aim}</div>
        </div>
        <div style={{flex:1}}>
          <div style={{fontFamily:PS, fontSize:24, color:'#fff', letterSpacing:2}}>PAR {PAR}</div>
          <div style={{marginTop:14, display:'flex', gap:8, alignItems:'center'}}>
            {[0,1,2].map(i=>(
              <div key={i} style={{width:22, height:22, background:i<darts?p.accent:'transparent', border:`2px solid ${i<darts?p.accent:INK+'0.28)'}`, boxShadow:i<darts?`0 0 8px ${p.accent}aa`:'none'}}></div>
            ))}
            <span style={{fontFamily:VT, fontSize:20, color:INK+'0.5)', letterSpacing:1, marginLeft:4}}>{darts}/3 DARTS</span>
          </div>
        </div>
      </div>

      {/* status line — the press-your-luck heartbeat */}
      <div style={{marginTop:15, padding:'13px 16px', background: done?`${t.col}16`:'rgba(255,255,255,0.04)', border:`2px solid ${done?t.col:INK+'0.16)'}`, display:'flex', alignItems:'center', gap:14}}>
        {!done ? (
          <span style={{fontFamily:VT, fontSize:24, color:INK+'0.7)', letterSpacing:1}}>▸ TEE OFF · 3 DARTS · <b style={{color:'#fff'}}>LAST DART COUNTS</b></span>
        ) : (
          <React.Fragment>
            <span style={{fontFamily:PS, fontSize:20, color:'#fff', letterSpacing:1}}>LYING {lie}</span>
            <span style={{fontFamily:PS, fontSize:16, color:t.col, letterSpacing:1, textShadow:`0 0 8px ${t.col}`}}>{t.term}</span>
            <span style={{flex:1}}/>
            {isResult
              ? <span style={{fontFamily:VT, fontSize:22, color:INK+'0.6)', letterSpacing:1}}>NEXT ▸ {p.next}</span>
              : <span style={{fontFamily:PS, fontSize:13, color:YELLOW, letterSpacing:1, textShadow:`0 0 6px ${YELLOW}88`}}>{left} DART{left===1?'':'S'} LEFT</span>}
          </React.Fragment>
        )}
      </div>
      {isResult && <div style={{position:'absolute', left:0, bottom:0, height:4, width:'100%', background:INK+'0.1)'}}><div style={{height:'100%', width:'62%', background:t.col, boxShadow:`0 0 10px ${t.col}`}}/></div>}
    </div>
  );
};

// ════════════════════════════════════════════════════════════════
// LEADERBOARD — full-width standalone, distance-legible. Fixes QA #3.
// Shows every player's total + vs-par + this-hole status; leader &
// active highlighted. Calm info styling (no glow) — this INFORMS.
// ════════════════════════════════════════════════════════════════
const V2Leaderboard = ({ players, hole, playoff }) => {
  const ordered = [...players].sort((a,b)=>a.total-b.total);
  return (
    <div style={{margin:'14px 16px 0', border:`2px solid ${INK}0.14)`}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', padding:'8px 14px', background:'rgba(255,255,255,0.03)', borderBottom:`2px solid ${INK}0.14)`}}>
        <span style={{fontFamily:PS, fontSize:10, color:INK+'0.7)', letterSpacing:2}}>{playoff?'PLAYOFF · TIED LEADERS':'LEADERBOARD'}</span>
        <span style={{fontFamily:VT, fontSize:17, color:INK+'0.45)', letterSpacing:2}}>LOWEST STROKES WINS</span>
      </div>
      {ordered.map((p,i)=>{
        const st = p.holeStroke;          // stroke on the CURRENT hole, or null
        const hs = st!=null ? termFor(st) : null;
        return (
          <div key={p.handle} style={{display:'grid', gridTemplateColumns:'40px 1fr 128px 72px 56px', alignItems:'center', gap:10, padding:'12px 16px', background: p.active?`${p.accent}14`:'transparent', borderBottom: i<ordered.length-1?`1px solid ${INK}0.08)`:'none', borderLeft: p.active?`4px solid ${p.accent}`:'4px solid transparent'}}>
            <div style={{fontFamily:PS, fontSize:16, color:i===0?YELLOW:INK+'0.4)', textShadow:i===0?`0 0 8px ${YELLOW}88`:'none'}}>{i+1}</div>
            <div style={{fontFamily:PS, fontSize:16, color:p.active?p.accent:'#fff', letterSpacing:1, textShadow:p.active?`0 0 8px ${p.accent}66`:'none'}}>{p.name.toUpperCase()}</div>
            {/* this-hole status */}
            <div style={{textAlign:'center'}}>
              {p.active
                ? <span style={{fontFamily:PS, fontSize:11, color:p.accent, letterSpacing:1, textShadow:`0 0 6px ${p.accent}`}}>▶ THROWING</span>
                : st!=null
                  ? <span style={{display:'inline-flex', alignItems:'center', gap:7}}><span style={{fontFamily:VT, fontSize:15, color:INK+'0.4)'}}>H{hole}</span><span style={{fontFamily:PS, fontSize:12, color:hs.col, padding:'3px 8px', border:`1.5px solid ${hs.col}`, background:`${hs.col}18`}}>{st}</span></span>
                  : <span style={{fontFamily:VT, fontSize:17, color:INK+'0.3)', letterSpacing:1}}>· TO PLAY</span>}
            </div>
            <div style={{textAlign:'right', fontFamily:PS, fontSize:24, color:'#fff'}}>{p.total}</div>
            <div style={{textAlign:'right', fontFamily:PS, fontSize:14, color:relCol(p.vsPar)}}>{relPar(p.vsPar)}</div>
          </div>
        );
      })}
    </div>
  );
};

// ════════════════════════════════════════════════════════════════
// INPUT CONSOLE — THE score-registering surface. The ONE loud, glowing,
// obviously-tappable zone; a labelled header names it explicitly so the
// 3 cells read as "this is where you score" and nothing else does.
// ════════════════════════════════════════════════════════════════
const V2Input = ({ hole, playoff }) => {
  const cells = playoff
    ? [ { z:'25',  sub:'BULL',   term:'BIRDIE', stroke:2 },
        { z:'50',  sub:'D-BULL', term:'ACE',    stroke:1 } ]
    : [ { z:`S${hole}`, sub:'SINGLE', stroke:3 },
        { z:`D${hole}`, sub:'DOUBLE', stroke:2 },
        { z:`T${hole}`, sub:'TRIPLE', stroke:1 } ];
  return (
    <div style={{margin:'0 16px 92px', marginTop:'auto', border:`3px solid ${GOLF}`, boxShadow:`0 0 28px ${GOLF}44, inset 0 0 40px ${GOLF}0d`, background:'rgba(61,255,142,0.03)'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', padding:'10px 16px', background:`${GOLF}1c`, borderBottom:`2px solid ${GOLF}66`}}>
        <span style={{fontFamily:PS, fontSize:13, color:GOLF, letterSpacing:2, textShadow:`0 0 8px ${GOLF}aa`}}>▼ TAP TO SCORE</span>
        <span style={{fontFamily:VT, fontSize:18, color:INK+'0.6)', letterSpacing:1}}>THROW AT <b style={{color:'#fff', fontFamily:PS, fontSize:12}}>{playoff?'BULL':hole}</b> · REGISTERS YOUR STROKE</span>
      </div>
      <div style={{display:'grid', gridTemplateColumns:`repeat(${cells.length},1fr)`, gap:12, padding:14}}>
        {cells.map(cel=>{
          const t = termFor(cel.stroke);
          return (
            <div key={cel.z} style={{background:`${t.col}16`, border:`3px solid ${t.col}`, boxShadow:`0 0 18px ${t.col}55, inset 0 -6px 0 ${t.col}22`, padding:'20px 0 16px', display:'flex', flexDirection:'column', alignItems:'center', gap:9}}>
              <div style={{fontFamily:PS, fontSize:playoff?34:38, color:t.col, textShadow:`0 0 14px ${t.col}cc`, letterSpacing:1}}>{cel.z}</div>
              <div style={{fontFamily:PS, fontSize:13, color:'#fff', letterSpacing:1}}>{t.term}</div>
              <div style={{fontFamily:VT, fontSize:18, color:INK+'0.6)', letterSpacing:1}}>{cel.stroke} STROKE{cel.stroke>1?'S':''}</div>
            </div>
          );
        })}
      </div>
      <div style={{padding:'0 14px 13px', textAlign:'center', fontFamily:VT, fontSize:18, color:INK+'0.5)', letterSpacing:1}}>…or hit <b style={{color:CYAN}}>✗ MISS</b> below = {playoff?'no score':'DOUBLE BOGEY · 5 strokes'}</div>
    </div>
  );
};

// ════════════════════════════════════════════════════════════════
// SCORECARD STRIP — WINDOWED (holes around the current), bigger cells,
// prominent SCORECARD affordance. Fixes QA #4.
// ════════════════════════════════════════════════════════════════
const V2ScoreStrip = ({ card, hole, holes }) => {
  const WIN = 7;
  let start = Math.max(1, hole - 3);
  start = Math.min(start, Math.max(1, holes - WIN + 1));
  const nums = Array.from({length:Math.min(WIN, holes)}, (_,i)=>start+i);
  return (
    <div style={{margin:'16px 16px 0'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:7}}>
        <span style={{fontFamily:PS, fontSize:10, color:INK+'0.6)', letterSpacing:1.5}}>YOUR CARD · HOLES {nums[0]}–{nums[nums.length-1]}</span>
        <span style={{fontFamily:PS, fontSize:11, color:CYAN, letterSpacing:1, padding:'5px 11px', border:`2px solid ${CYAN}`, textShadow:`0 0 6px ${CYAN}88`}}>SCORECARD ▸</span>
      </div>
      <div style={{display:'grid', gridTemplateColumns:`repeat(${nums.length},1fr)`, gap:6}}>
        {nums.map(h=>{
          const st = card[h-1];
          const played = st!=null;
          const cur = h===hole;
          const t = played?termFor(st):null;
          return (
            <div key={h} style={{textAlign:'center'}}>
              <div style={{fontFamily:VT, fontSize:16, color:cur?YELLOW:INK+'0.4)', marginBottom:3}}>{h}</div>
              <div style={{height:44, display:'flex', alignItems:'center', justifyContent:'center', border:`2px solid ${cur?YELLOW:played?t.col:INK+'0.12)'}`, background:cur?`${YELLOW}1c`:played?`${t.col}16`:'transparent', boxShadow:cur?`0 0 10px ${YELLOW}66`:'none', fontFamily:PS, fontSize:16, color:cur?YELLOW:played?t.col:INK+'0.25)'}}>{played?st:cur?'▶':'·'}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ── sudden-death overlay (the ONLY remaining moment overlay) ─────
const V2Overlay = ({ tint, children }) => (
  <div style={{position:'absolute', inset:0, zIndex:8, display:'flex', alignItems:'center', justifyContent:'center', background:`radial-gradient(ellipse at center, ${tint}22 0%, rgba(5,0,14,0.9) 70%)`, backdropFilter:'blur(2px)'}}>{children}</div>
);

// ════════════════════════════════════════════════════════════════
// COCKPIT — hero · leaderboard · input · strip · action bar
// ════════════════════════════════════════════════════════════════
const V2Cockpit = ({ s }) => (
  <V2Frame>
    <V2TopBar hole={s.hole} holes={s.holes} playoff={s.playoff}/>
    <V2Hero p={s.active} hole={s.hole} darts={s.darts} lie={s.lie} mode={s.mode} target={s.target} playoff={s.playoff}/>
    <V2Leaderboard players={s.players} hole={s.hole} playoff={s.playoff}/>
    {!s.playoff && <V2ScoreStrip card={s.card} hole={s.hole} holes={s.holes}/>}
    <V2Input hole={s.hole} playoff={s.playoff}/>
    {s.overlay==='sudden' && (
      <V2Overlay tint={RED}>
        <div style={{textAlign:'center'}}>
          <div style={{fontSize:46}}>⛳</div>
          <div style={{fontFamily:PS, fontSize:44, color:RED, letterSpacing:2, textShadow:`0 0 24px ${RED}`, marginTop:12, lineHeight:1.15}}>SUDDEN<br/>DEATH</div>
          <div style={{fontFamily:VT, fontSize:26, color:'#fff', letterSpacing:2, marginTop:16}}>TIED AT {s.active.total} STROKES · PLAYOFF</div>
          <div style={{fontFamily:PS, fontSize:13, color:YELLOW, letterSpacing:1, marginTop:14, textShadow:`0 0 8px ${YELLOW}88`}}>19 → 20 → BULL · LOWEST STROKE WINS</div>
          <div style={{fontFamily:VT, fontSize:16, color:INK+'0.4)', letterSpacing:2, marginTop:18}}>TAP TO CONTINUE · AUTO 1s</div>
        </div>
      </V2Overlay>
    )}
    <V2ActionBar/>
  </V2Frame>
);

// ── between-holes transition banner variant (state 4) ────────────
const V2Between = ({ s }) => (
  <V2Frame>
    <V2TopBar hole={s.hole} holes={s.holes}/>
    <div style={{margin:'14px 16px 0', padding:'12px 16px', background:`${GOLF}14`, border:`2px solid ${GOLF}66`, display:'flex', alignItems:'center', gap:14}}>
      <span style={{fontFamily:PS, fontSize:12, color:GOLF, letterSpacing:1, textShadow:`0 0 6px ${GOLF}`}}>✓ HOLE {s.hole-1} DONE</span>
      <span style={{flex:1, fontFamily:VT, fontSize:22, color:INK+'0.6)', letterSpacing:1}}>everyone through — new tee</span>
      <span style={{fontFamily:PS, fontSize:12, color:YELLOW, letterSpacing:1}}>▸ HOLE {s.hole}</span>
    </div>
    <V2Hero p={s.active} hole={s.hole} darts={0} lie={null} mode="teeoff"/>
    <V2Leaderboard players={s.players} hole={s.hole}/>
    <V2ScoreStrip card={s.card} hole={s.hole} holes={s.holes}/>
    <V2Input hole={s.hole}/>
    <V2ActionBar/>
  </V2Frame>
);

// ── scenarios / fixtures ─────────────────────────────────────────
const mkCard = (arr) => { const c = Array(18).fill(null); arr.forEach((s,i)=>c[i]=s); return c; };
const sum = (c) => c.reduce((a,v)=>a+(v||0),0);
const thru = (c) => c.filter(v=>v!=null).length;
const vsp = (c) => sum(c) - PAR*thru(c);

// six holes on the board; hole 7 in progress
const V2_CARDS = {
  JON: [3,2,3,1,3,3],
  MIA: [3,3,2,3,3,2, 2],
  KAR: [3,3,3,3,2,3, 3],
  PER: [3,3,4,3,3,3],
};
const V2_META = { JON:['Jonas',CYAN], MIA:['Mia',YELLOW], KAR:['Kari',MAGENTA], PER:['Per',GREEN] };
const V2_NEXT = { JON:'PER', MIA:'—', KAR:'—', PER:'JON' };

// per-hole status for the CURRENT hole (round-based): played players show
// their stroke; the active player is throwing; the rest are to-play.
const mkPlayers = (activeKey, hole) => Object.keys(V2_CARDS).map(k=>{
  const [name,accent] = V2_META[k];
  const c = mkCard(V2_CARDS[k]);
  const holeStroke = c[hole-1] ?? null;    // null → not played this hole
  return { handle:k, name, accent, card:c, total:sum(c), vsPar:vsp(c), active:k===activeKey, holeStroke, next:V2_NEXT[k] };
});
const activeOf = (players) => players.find(p=>p.active);

function state(activeKey, hole, darts, lie, mode, opts={}){
  const players = mkPlayers(activeKey, hole);
  const active = { ...activeOf(players) };
  // the active player's own current-hole cell isn't "played" yet
  active.holeStroke = null;
  const withActiveClear = players.map(p=>p.active?{...p, holeStroke:null}:p);
  return { hole, holes:18, players:withActiveClear, active, card:active.card, darts, lie, mode, ...opts };
}

const V2_STATES = {
  teeoff:  state('JON', 7, 0, null, 'teeoff'),
  mid:     state('JON', 7, 2, 2,    'mid'),
  result:  (()=>{ const st = state('JON', 7, 2, 2, 'result'); return st; })(),
  between: state('PER', 8, 0, null, 'teeoff'),
  sudden:  (()=>{ const players = mkPlayers('JON',18).slice(0,2).map(p=>({...p, total:54, vsPar:0, holeStroke:null}));
                  const active = {...players[0], total:54, vsPar:0};
                  return { hole:18, holes:18, players, active, card:active.card, darts:0, lie:null, mode:'teeoff', overlay:'sudden' }; })(),
  playoff: (()=>{ const players = mkPlayers('JON',18).slice(0,2).map(p=>({...p, total:54, vsPar:0, holeStroke:null, next:'—'}));
                  const active = {...players[0], total:54, vsPar:0};
                  return { hole:18, holes:18, players, active, card:active.card, darts:1, lie:2, mode:'mid', playoff:true, target:'BULL' }; })(),
};

// ════════════════════════════════════════════════════════════════
// FULL SCORECARD SHEET — approved as-is; carried across, term fn updated
// ════════════════════════════════════════════════════════════════
const V2ScoreSheet = ({ hole, holes, players }) => (
  <V2Frame>
    <V2TopBar hole={hole} holes={holes}/>
    <div style={{padding:'18px 16px 0', display:'flex', alignItems:'center', justifyContent:'space-between'}}>
      <div style={{fontFamily:PS, fontSize:15, color:CYAN, letterSpacing:2, textShadow:`0 0 8px ${CYAN}88`}}>SCORECARD</div>
      <div style={{fontFamily:VT, fontSize:18, color:INK+'0.5)', letterSpacing:2}}>PAR {PAR} EACH · ✕ CLOSE</div>
    </div>
    <div style={{margin:'16px 12px', border:`2px solid ${INK}0.16)`, overflow:'hidden'}}>
      <div style={{display:'grid', gridTemplateColumns:`80px repeat(${holes},1fr) 56px`, background:'rgba(255,255,255,0.04)', borderBottom:`2px solid ${INK}0.16)`}}>
        <div style={{padding:'10px 8px', fontFamily:PS, fontSize:9, color:INK+'0.6)', letterSpacing:1}}>HOLE</div>
        {Array.from({length:holes}).map((_,i)=>(<div key={i} style={{padding:'10px 0', textAlign:'center', fontFamily:VT, fontSize:16, color:(i+1)===hole?YELLOW:INK+'0.55)', borderLeft:`1px solid ${INK}0.06)`}}>{i+1}</div>))}
        <div style={{padding:'10px 0', textAlign:'center', fontFamily:PS, fontSize:9, color:YELLOW, borderLeft:`1px solid ${INK}0.14)`}}>TOT</div>
      </div>
      <div style={{display:'grid', gridTemplateColumns:`80px repeat(${holes},1fr) 56px`, background:'rgba(255,255,255,0.015)', borderBottom:`1px solid ${INK}0.08)`}}>
        <div style={{padding:'8px', fontFamily:VT, fontSize:16, color:INK+'0.45)'}}>PAR</div>
        {Array.from({length:holes}).map((_,i)=>(<div key={i} style={{padding:'8px 0', textAlign:'center', fontFamily:VT, fontSize:16, color:INK+'0.32)', borderLeft:`1px solid ${INK}0.05)`}}>{PAR}</div>))}
        <div style={{padding:'8px 0', textAlign:'center', fontFamily:VT, fontSize:16, color:INK+'0.4)', borderLeft:`1px solid ${INK}0.14)`}}>{PAR*holes}</div>
      </div>
      {players.map((p,ri)=>(
        <div key={p.handle} style={{display:'grid', gridTemplateColumns:`80px repeat(${holes},1fr) 56px`, background:p.active?`${p.accent}10`:'transparent', borderBottom:ri<players.length-1?`1px solid ${INK}0.08)`:'none'}}>
          <div style={{padding:'11px 8px', fontFamily:PS, fontSize:11, color:p.active?p.accent:PHOSPHOR, letterSpacing:1, display:'flex', alignItems:'center', gap:4}}>{p.active&&<span>▶</span>}{p.handle}</div>
          {Array.from({length:holes}).map((_,i)=>{
            const st = p.card[i]; const played = st!=null; const t = played?termFor(st):null; const cur = (i+1)===hole && p.active;
            return (<div key={i} style={{padding:'11px 0', textAlign:'center', borderLeft:`1px solid ${INK}0.05)`, background:cur?`${YELLOW}16`:'transparent', fontFamily:PS, fontSize:12, color:played?t.col:cur?YELLOW:INK+'0.18)', textShadow:played&&st===1?`0 0 6px ${t.col}`:'none'}}>{played?st:cur?'▶':'·'}</div>);
          })}
          <div style={{padding:'11px 0', textAlign:'center', borderLeft:`1px solid ${INK}0.14)`, fontFamily:PS, fontSize:13, color:'#fff'}}>{p.total}</div>
        </div>
      ))}
    </div>
    <div style={{display:'flex', justifyContent:'center', gap:18, flexWrap:'wrap', padding:'2px 16px'}}>
      {[1,2,3,4,5].map(st=>{ const t=termFor(st); return (
        <div key={st} style={{display:'flex', alignItems:'center', gap:6}}>
          <div style={{width:18, height:18, border:`1.5px solid ${t.col}`, background:`${t.col}22`, fontFamily:PS, fontSize:8, color:t.col, display:'flex', alignItems:'center', justifyContent:'center'}}>{st}</div>
          <span style={{fontFamily:VT, fontSize:16, color:INK+'0.6)', letterSpacing:1}}>{t.term}</span>
        </div>); })}
    </div>
    <V2ActionBar/>
  </V2Frame>
);
const V2_SHEET     = (()=>{ const players = mkPlayers('JON',7); return { hole:7,  holes:18, players }; })();
const V2_SHEET_FIN = (()=>{ const fin = { JON:[3,3,2,3,3,3,3,1,3,3,2,3,3,3,2,3,3,2], KAR:[3,3,3,3,2,3,3,3,3,2,3,3,5,3,3,2,3,3], PER:[3,3,3,3,3,3,3,3,5,3,3,3,3,3,3,2,3,5], MIA:[3,3,5,3,3,3,3,3,3,3,5,3,3,3,3,3,3,5] };
  const players = Object.keys(fin).map(k=>{ const [name,accent]=V2_META[k]; const c=mkCard(fin[k]); return { handle:k, name, accent, card:c, total:sum(c), vsPar:vsp(c) }; }).sort((a,b)=>a.total-b.total);
  return { hole:19, holes:18, players }; })();

// ════════════════════════════════════════════════════════════════
// SPEC / FASIT CARD — v2 layout round
// ════════════════════════════════════════════════════════════════
const V2Row = ({ label, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    {hex && <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}/>}
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{label}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);
const V2SpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1300, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:13, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Golf · cockpit v2 · layout fasit</div>
      <div style={{fontFamily:'"Archivo","Inter",sans-serif', fontSize:26, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>One loud input, everything else a calm readout</div>
    </div>
    <div style={{padding:'11px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter",sans-serif', fontSize:13, fontWeight:800, color:'#2a4a36', marginBottom:4}}>The idea</div>
      <div style={{fontFamily:'"Inter",sans-serif', fontSize:12.5, color:'#2a4a36', lineHeight:1.5}}>Only the <b>3 S/D/T cells register score</b>. So they are the one glowing, bordered, "▼ TAP TO SCORE" console — the single obviously-interactive surface. Hero, leaderboard and strip are flat, glow-free <b>readouts</b> that only inform. That hierarchy is the whole round.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter",sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>QA fixes (Galaxy Tab pass)</div>
      <V2Row label="1 · Freed middle space — no dartboard to host" val="hero + big board" hex={GOLF}/>
      <V2Row label="2 · Aim signal — HOLE number ~130px, glowing" val="legible @2.4m" hex={YELLOW}/>
      <V2Row label="3 · Standalone leaderboard back, full-width" val="totals + this-hole" hex={MAGENTA}/>
      <V2Row label="4 · Windowed scorecard strip (7 holes, big)" val="+ SCORECARD ▸" hex={CYAN}/>
    </div>
    <div style={{padding:'11px 14px', background:'#fbe9d8', border:'1px solid rgba(201,100,66,0.35)'}}>
      <div style={{fontFamily:'"Inter",sans-serif', fontSize:13, fontWeight:800, color:'#5a442f', marginBottom:4}}>Removed in v2 (rules pinned)</div>
      <div style={{fontFamily:'"Inter",sans-serif', fontSize:12.5, color:'#5a442f', lineHeight:1.5}}><b>No LOCK IN</b> → standard 3-action bar (UNDO · MISS · MENU). <b>No ACE overlay</b>, <b>no winner overlay</b> (post-game is the sole winner surface). Mid-hole now reads <b>LYING n — m DARTS LEFT</b>; the finished hole gets a <b>1s HOLE RESULT</b> readout naming the finishing player.</div>
    </div>
    <div style={{padding:'11px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter",sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Stroke values + term colours (fasit)</div>
      <div style={{display:'flex', gap:14, flexWrap:'wrap', marginTop:4}}>
        {[['T',1,'ACE',CYAN],['D',2,'BIRDIE',GREEN],['S',3,'PAR',PHOSPHOR],['+1',4,'BOGEY',ORANGE],['MISS',5,'DBL BOGEY',RED]].map(([z,st,lbl,col])=>(
          <div key={lbl} style={{display:'flex', alignItems:'center', gap:6}}>
            <div style={{width:15, height:15, background:col, border:'1px solid rgba(0,0,0,0.2)'}}/>
            <span style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11.5, color:'#2a251f'}}><b>{z}</b>={st}·{lbl}</span>
          </div>
        ))}
      </div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter",sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Cockpit states (shipped set, unchanged)</div>
      {[
        ['1 · Tee off','0 darts · "TEE OFF · 3 DARTS · LAST DART COUNTS". Input fully live.'],
        ['2 · Mid-hole','LYING n + term + m DARTS LEFT. The press-your-luck beat — no button, just the readout.'],
        ['3 · Hole result','1s window: term-coloured frame, LYING n, finishing player named, NEXT ▸. No overlay.'],
        ['4 · Between holes','✓ HOLE n done banner → new tee, board updated, next player active.'],
        ['5 · Sudden death','Red overlay on start (tap / 1s auto). Only remaining moment overlay.'],
        ['6 · Playoff','PLAYOFF top-bar · BULL target = TWO cells (25/50) · leaderboard = tied leaders only.'],
        ['7 · Winner = POST-GAME','No in-cockpit winner surface (approved, unchanged from the shipped build).'],
      ].map(([t,b])=>(
        <div key={t} style={{padding:'6px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{fontFamily:'"Inter",sans-serif', fontSize:12.5, fontWeight:700, color:'#2a251f'}}>{t}</div>
          <div style={{fontFamily:'"Inter",sans-serif', fontSize:11.5, lineHeight:1.4, color:'#5a544a', marginTop:2}}>{b}</div>
        </div>
      ))}
    </div>
    <div style={{marginTop:'auto', padding:'11px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter",sans-serif', fontSize:12.5, lineHeight:1.5, color:'#2a4a36'}}><b>Unchanged / reused:</b> CrtFrame + scanlines, TopBar, 3-action ActionBar, ATC S/D/T zone input, the full scorecard sheet (GFScoreSheet), home / setup / post-game — all approved as built. Tokens only; brand = existing <b>green</b>. Fonts Press Start 2P / VT323. No border-radius. English strings.</div>
    </div>
  </div>
);

// ── Canvas ───────────────────────────────────────────────────────
const GolfCockpitV2 = () => (
  <React.Fragment>
    <DCSection id="v2-cockpit" title="Golf cockpit v2 — layout round"
      subtitle="Pure layout pass on the tablet-QA feedback. Golf's only score-registering surface is the three S/D/T cells, so they are the one loud, glowing '▼ TAP TO SCORE' console; the hero target, the full-width leaderboard and the windowed scorecard are calm, distance-legible readouts. LOCK IN is gone (standard 3-action bar); no ACE / winner overlay. Stroke: T=1 ACE · D=2 BIRDIE · S=3 PAR · miss=5 DOUBLE BOGEY.">
      <DCArtboard id="v2-1" label="1 · Tee off" width={V2_W} height={V2_H}><V2Cockpit s={V2_STATES.teeoff}/></DCArtboard>
      <DCArtboard id="v2-2" label="2 · Mid-hole · LYING n — m DARTS LEFT" width={V2_W} height={V2_H}><V2Cockpit s={V2_STATES.mid}/></DCArtboard>
      <DCArtboard id="v2-3" label="3 · Hole result (1s window)" width={V2_W} height={V2_H}><V2Cockpit s={V2_STATES.result}/></DCArtboard>
      <DCArtboard id="v2-4" label="4 · Between holes / next tee" width={V2_W} height={V2_H}><V2Between s={V2_STATES.between}/></DCArtboard>
      <DCArtboard id="v2-5" label="5 · Sudden death (overlay)" width={V2_W} height={V2_H}><V2Cockpit s={V2_STATES.sudden}/></DCArtboard>
      <DCArtboard id="v2-6" label="6 · Playoff · BULL = two cells" width={V2_W} height={V2_H}><V2Cockpit s={V2_STATES.playoff}/></DCArtboard>
    </DCSection>

    <DCSection id="v2-card" title="Golf — scorecard (full sheet · approved, carried across)"
      subtitle="Holes × players, par row, totals, term colouring + legend. Reached from the cockpit's SCORECARD ▸ and from post-game. Unchanged from the shipped build.">
      <DCArtboard id="v2-sheet" label="Scorecard · mid-game (hole 7)" width={V2_W} height={V2_H}><V2ScoreSheet {...V2_SHEET}/></DCArtboard>
      <DCArtboard id="v2-sheet-fin" label="Scorecard · finished round" width={V2_W} height={V2_H}><V2ScoreSheet {...V2_SHEET_FIN}/></DCArtboard>
    </DCSection>

    <DCSection id="v2-spec" title="Golf v2 — layout fasit"
      subtitle="What changed and why: one interactive console vs. calm readouts, the four QA fixes, the pinned rule removals (LOCK IN / overlays), stroke values and the unchanged/reused inventory.">
      <DCArtboard id="v2-spec-card" label="Spec · Golf v2" width={680} height={1300}><V2SpecCard/></DCArtboard>
    </DCSection>
  </React.Fragment>
);
window.GolfCockpitV2 = GolfCockpitV2;
