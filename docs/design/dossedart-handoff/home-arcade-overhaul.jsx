// DOSSEDART — Home (Arcade), overhaul round
// • Footer "PRESS START TO PLAY" → STATS / HISTORY / SETTINGS (cabinet buttons)
// • Leaderboard: 3 variants to choose from
//     A. Podium — arcade-cabinet style 3-block
//     B. Tighter list — same structure, better proportions + #1 hero row
//     C. Champion card + two — hero card for #1, compact rows below

const AW = 820, AH = 1180;

// 3-letter arcade handles (classic high-score tradition)
const TOP = [
  { handle:'AND', name:'Andreas', rating: 1568, w: 89, form:['W','W','L','W','W'] },
  { handle:'JON', name:'Jonas',   rating: 1422, w: 51, form:['L','W','L','W','L'] },
  { handle:'MIA', name:'Mia',     rating: 1387, w: 38, form:['W','L','L','W','L'] },
];
const MODES = [
  { k:'cricket', label:'Cricket',          em:'🎯' },
  { k:'atc',     label:'Around the Clock', em:'🕒' },
  { k:'killer',  label:'Killer',           em:'🔪' },
  { k:'halve',   label:'Halve It',         em:'✂️' },
  { k:'shanghai',label:'Shanghai',         em:'🐉' },
];
const X01 = [
  { n:301, em:'🥉', tag:'short'   },
  { n:501, em:'🍻', tag:'classic' },
  { n:701, em:'🏆', tag:'long'    },
];

// ─────────────────────────────────────────────────────────────────
// Cabinet button — used in the new footer
// ─────────────────────────────────────────────────────────────────
const CabBtn = ({ label, sub, color, icon }) => (
  <div style={{flex:1, padding:'14px 12px', background:'#0a0014', borderTop:`3px solid ${color}`, position:'relative', display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
    <div style={{position:'absolute', top:-8, left:'50%', transform:'translateX(-50%)', width:18, height:8, borderRadius:'4px 4px 0 0', background:color, boxShadow:`0 0 6px ${color}`}}/>
    <div style={{fontSize:22, lineHeight:1}}>{icon}</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:12, color:color, letterSpacing:1, textShadow:`0 0 6px ${color}88`}}>{label}</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>{sub}</div>
  </div>
);

const NewFooter = () => (
  <div style={{display:'flex', alignItems:'stretch', borderTop:'2px solid #FFD200', background:'#000', position:'relative'}}>
    {/* coin-slot detail */}
    <div style={{position:'absolute', top:-2, left:0, right:0, height:2, background:'linear-gradient(90deg, #FF00AA 0%, #FFD200 50%, #00E5FF 100%)'}}/>
    <CabBtn label="STATS"    sub="P-1"   color="#00E5FF" icon="📊" />
    <CabBtn label="HISTORY"  sub="LOG"   color="#FFD200" icon="📜" />
    <CabBtn label="SETTINGS" sub="CFG"   color="#FF00AA" icon="⚙" />
  </div>
);

// ─────────────────────────────────────────────────────────────────
// Shared arcade chrome
// ─────────────────────────────────────────────────────────────────
const Header = () => (
  <div style={{padding:'22px 28px 18px', background:'#000', borderBottom:'2px solid #FF00AA', textAlign:'center'}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'#00E5FF', letterSpacing:4}}>★ ★ ★  INSERT COIN  ★ ★ ★</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:36, color:'#FFD200', textShadow:'0 0 10px #FFD200, 4px 4px 0 #FF00AA', marginTop:14, letterSpacing:1, lineHeight:1.3}}>DOSSE<br/>DART</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:'#fff', marginTop:10, letterSpacing:2}}>©2024 OFFICE GAMES INC.</div>
  </div>
);

const X01Block = () => (
  <div style={{padding:'18px 28px 0'}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#00E5FF', marginBottom:14, letterSpacing:1}}>► PLAYER 1 SELECT</div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:10}}>
      {X01.map((r, i) => {
        const hero = i===1; const c = hero?'#FFD200':'#FF00AA';
        return (
          <div key={r.n} style={{padding:'18px 10px', background:'#1a0030', border:`3px solid ${c}`, boxShadow:`0 0 16px ${c}66, inset 0 0 16px ${c}33`, textAlign:'center'}}>
            <div style={{fontSize:32, marginBottom:6}}>{r.em}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:28, color:c, letterSpacing:1}}>{r.n}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'#fff', opacity:.7, marginTop:6}}>{r.tag.toUpperCase()}</div>
          </div>
        );
      })}
    </div>
  </div>
);

const ModesBlock = () => (
  <div style={{padding:'18px 28px 18px', flex:1}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#00E5FF', marginBottom:14, letterSpacing:1}}>► OR PICK A LEVEL</div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8}}>
      {MODES.map((m) => (
        <div key={m.k} style={{padding:'12px 14px', background:'#1a0030', border:'2px solid #00E5FF', display:'flex', alignItems:'center', gap:12, boxShadow:'0 0 8px rgba(0,229,255,0.4)'}}>
          <div style={{fontSize:26}}>{m.em}</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#fff', letterSpacing:1, lineHeight:1.4}}>{m.label.toUpperCase()}</div>
        </div>
      ))}
      <div style={{padding:'12px 14px', border:'2px dashed rgba(255,0,170,0.4)', display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.5)'}}>?? COMING ??</div>
    </div>
  </div>
);

const HomeShell = ({ leaderboard }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:AW, height:AH, background:'#0a0014', color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}/>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}/>
      <Header/>
      {leaderboard}
      <X01Block/>
      <ModesBlock/>
      <NewFooter/>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────────
// Variant A — PODIUM
// 3 cabinet-style podium blocks.  #1 tallest, centred with crown.
// Each block stamped with rank ("1ST"/"2ND"/"3RD"), 3-letter handle,
// score, and full name.  Feels like a real arcade-cabinet hi-score
// reveal screen.
// ─────────────────────────────────────────────────────────────────
const PodiumBlock = ({ p, rank, color, height, crown }) => (
  <div style={{display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
    {crown && (
      <div style={{fontSize:34, lineHeight:1, filter:`drop-shadow(0 0 8px ${color})`}}>👑</div>
    )}
    {!crown && <div style={{height:34}}/>}
    {/* tag */}
    <div style={{padding:'4px 10px', background:color, color:'#0a0014', fontFamily:'"Press Start 2P", monospace', fontSize:11, letterSpacing:1, boxShadow:`0 0 10px ${color}`}}>{rank}</div>
    {/* podium block */}
    <div style={{width:'100%', height, background:'#1a0030', border:`3px solid ${color}`, boxShadow:`0 0 16px ${color}66, inset 0 0 24px ${color}22`, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', position:'relative', padding:'10px 6px'}}>
      {/* corner stars */}
      <div style={{position:'absolute', top:6, left:8, fontFamily:'"VT323", monospace', fontSize:14, color:color, opacity:.7}}>★</div>
      <div style={{position:'absolute', top:6, right:8, fontFamily:'"VT323", monospace', fontSize:14, color:color, opacity:.7}}>★</div>
      <div style={{position:'absolute', bottom:6, left:8, fontFamily:'"VT323", monospace', fontSize:14, color:color, opacity:.7}}>★</div>
      <div style={{position:'absolute', bottom:6, right:8, fontFamily:'"VT323", monospace', fontSize:14, color:color, opacity:.7}}>★</div>
      {/* handle */}
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:crown?34:26, color:color, letterSpacing:2, textShadow:`0 0 10px ${color}aa`, lineHeight:1}}>{p.handle}</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:crown?28:22, color:'#fff', marginTop:8, lineHeight:1}}>{p.rating}</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'#fff', opacity:.55, letterSpacing:1, marginTop:2}}>W{p.w}%</div>
    </div>
    {/* base label */}
    <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.6)', letterSpacing:2, marginTop:2}}>{p.name.toUpperCase()}</div>
  </div>
);

const LeaderboardA = () => (
  <div style={{padding:'18px 28px 12px', borderBottom:'1px dashed rgba(255,0,170,0.4)'}}>
    <div style={{display:'flex', alignItems:'center', justifyContent:'center', gap:14, marginBottom:6}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'#FF00AA'}}>━━━━</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:'#00E5FF', letterSpacing:1.5}}>★ HIGH SCORES ★</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'#FF00AA'}}>━━━━</div>
    </div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1.05fr 1fr', gap:10, alignItems:'flex-end', marginTop:10}}>
      <PodiumBlock p={TOP[1]} rank="2ND" color="#00E5FF" height={140} />
      <PodiumBlock p={TOP[0]} rank="1ST" color="#FFD200" height={186} crown />
      <PodiumBlock p={TOP[2]} rank="3RD" color="#FF00AA" height={120} />
    </div>
    <div style={{textAlign:'center', fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.55)', marginTop:10, letterSpacing:2}}>▼ FULL RANKING ▼</div>
  </div>
);

// ─────────────────────────────────────────────────────────────────
// Variant B — TIGHTER LIST
// Same idea, better proportions: bigger rows, clearer columns,
// #1 gets a hero treatment with glow + medal.  No more cramped grid.
// ─────────────────────────────────────────────────────────────────
const RowB = ({ p, i }) => {
  const hero = i===0;
  const colors = ['#FFD200','#00E5FF','#FF00AA'];
  const c = colors[i];
  const medals = ['🥇','🥈','🥉'];
  return (
    <div style={{
      display:'grid',
      gridTemplateColumns:'46px 80px 1fr 110px 70px',
      alignItems:'center',
      gap:12,
      padding: hero ? '14px 14px' : '10px 14px',
      background: hero ? 'rgba(255,210,0,0.08)' : 'transparent',
      border: hero ? '2px solid #FFD200' : '2px solid transparent',
      borderBottom: !hero ? '1px solid rgba(255,255,255,0.08)' : '2px solid #FFD200',
      boxShadow: hero ? '0 0 14px rgba(255,210,0,0.2)' : 'none',
      marginBottom: hero ? 8 : 0,
    }}>
      <div style={{fontSize: hero?28:22, textAlign:'center'}}>{medals[i]}</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize: hero?18:14, color:c, letterSpacing:1.5, textShadow: hero?`0 0 8px ${c}88`:'none'}}>{p.handle}</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize: hero?26:22, color:'#fff', letterSpacing:1.5}}>{p.name.toUpperCase()}</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize: hero?18:14, color:c, textAlign:'right', letterSpacing:.5}}>{p.rating}</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize: hero?20:18, color:'rgba(255,255,255,0.55)', textAlign:'right'}}>W{p.w}%</div>
    </div>
  );
};

const LeaderboardB = () => (
  <div style={{padding:'18px 28px 14px', borderBottom:'1px dashed rgba(255,0,170,0.4)'}}>
    <div style={{display:'flex', alignItems:'center', justifyContent:'center', gap:14, marginBottom:14}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'#FF00AA'}}>━━━━</div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:'#00E5FF', letterSpacing:1.5}}>★ HIGH SCORES ★</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'#FF00AA'}}>━━━━</div>
    </div>
    {/* column header */}
    <div style={{display:'grid', gridTemplateColumns:'46px 80px 1fr 110px 70px', gap:12, padding:'0 14px 6px', fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.4)', letterSpacing:2, borderBottom:'1px solid rgba(255,0,170,0.3)'}}>
      <div style={{textAlign:'center'}}>RANK</div>
      <div>HANDLE</div>
      <div>PLAYER</div>
      <div style={{textAlign:'right'}}>RATING</div>
      <div style={{textAlign:'right'}}>WIN%</div>
    </div>
    <div style={{paddingTop:10}}>
      {TOP.map((p, i) => <RowB key={i} p={p} i={i}/>)}
    </div>
    <div style={{textAlign:'center', fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.45)', marginTop:8, letterSpacing:2}}>▼ MORE ▼</div>
  </div>
);

// ─────────────────────────────────────────────────────────────────
// Variant C — CHAMPION CARD + TWO
// #1 gets a full-width hero card (handle, name, rating, recent form
// W/L pips). #2 and #3 sit below as compact rows.
// ─────────────────────────────────────────────────────────────────
const FormPips = ({ form, color }) => (
  <div style={{display:'flex', gap:4}}>
    {form.map((f, i) => (
      <div key={i} style={{
        width:18, height:18,
        background: f==='W' ? color : 'transparent',
        border: `1.5px solid ${f==='W' ? color : 'rgba(255,255,255,0.3)'}`,
        color: f==='W' ? '#0a0014' : 'rgba(255,255,255,0.4)',
        display:'flex', alignItems:'center', justifyContent:'center',
        fontFamily:'"Press Start 2P", monospace', fontSize:9,
      }}>{f}</div>
    ))}
  </div>
);

const LeaderboardC = () => {
  const champ = TOP[0];
  return (
    <div style={{padding:'18px 28px 14px', borderBottom:'1px dashed rgba(255,0,170,0.4)'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:14}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:'#00E5FF', letterSpacing:1.5}}>★ HIGH SCORES</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.45)', letterSpacing:2}}>SEASON 03 ▸</div>
      </div>

      {/* Champion card */}
      <div style={{position:'relative', padding:'16px 18px', background:'rgba(255,210,0,0.08)', border:'3px solid #FFD200', boxShadow:'0 0 18px rgba(255,210,0,0.25), inset 0 0 24px rgba(255,210,0,0.08)', marginBottom:10}}>
        <div style={{position:'absolute', top:-12, left:14, padding:'3px 10px', background:'#FFD200', color:'#0a0014', fontFamily:'"Press Start 2P", monospace', fontSize:10, letterSpacing:1}}>★ CHAMPION</div>
        <div style={{position:'absolute', top:8, right:12, fontSize:24}}>👑</div>
        <div style={{display:'grid', gridTemplateColumns:'auto 1fr auto', gap:14, alignItems:'center'}}>
          <div style={{padding:'10px 14px', background:'#0a0014', border:'2px solid #FFD200', fontFamily:'"Press Start 2P", monospace', fontSize:30, color:'#FFD200', letterSpacing:2, textShadow:'0 0 10px #FFD200aa'}}>{champ.handle}</div>
          <div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:26, color:'#fff', letterSpacing:1.5, lineHeight:1}}>{champ.name.toUpperCase()}</div>
            <div style={{display:'flex', alignItems:'center', gap:10, marginTop:8}}>
              <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.5)', letterSpacing:1}}>FORM</div>
              <FormPips form={champ.form} color="#FFD200"/>
            </div>
          </div>
          <div style={{textAlign:'right'}}>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:24, color:'#FFD200', letterSpacing:1, textShadow:'0 0 8px #FFD20088'}}>{champ.rating}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.55)', marginTop:4}}>W{champ.w}% · {champ.form.length}G</div>
          </div>
        </div>
      </div>

      {/* Rows for 2 & 3 */}
      {[1,2].map(idx => {
        const p = TOP[idx];
        const c = idx===1 ? '#00E5FF' : '#FF00AA';
        const medal = idx===1 ? '🥈' : '🥉';
        return (
          <div key={idx} style={{display:'grid', gridTemplateColumns:'30px 60px 1fr auto auto', gap:12, alignItems:'center', padding:'8px 6px', borderBottom: idx===1 ? '1px solid rgba(255,255,255,0.08)' : 'none'}}>
            <div style={{fontSize:18, textAlign:'center'}}>{medal}</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, letterSpacing:1.5}}>{p.handle}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:'#fff', letterSpacing:1}}>{p.name.toUpperCase()}</div>
            <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.45)', letterSpacing:1}}>W{p.w}%</div>
            <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, letterSpacing:.5, minWidth:60, textAlign:'right'}}>{p.rating}</div>
          </div>
        );
      })}

      <div style={{textAlign:'center', fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.45)', marginTop:6, letterSpacing:2}}>▼ FULL RANKING (12) ▼</div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────────
const HomeArcadeOverhaul = () => (
  <DCSection
    id="ah-home"
    title="Home — leaderboard treatment"
    subtitle="Footer flipped from “PRESS START TO PLAY” to a 3-button cabinet (STATS / HISTORY / SETTINGS). Three options for the high-score block — pick the one that feels right or call out a hybrid.">
    <DCArtboard id="podium"  label="A · Podium — cabinet hi-score reveal"        width={AW} height={AH}><HomeShell leaderboard={<LeaderboardA/>}/></DCArtboard>
    <DCArtboard id="list"    label="B · Tight list — #1 hero row + columns"      width={AW} height={AH}><HomeShell leaderboard={<LeaderboardB/>}/></DCArtboard>
    <DCArtboard id="champ"   label="C · Champion card + two — recent-form pips"  width={AW} height={AH}><HomeShell leaderboard={<LeaderboardC/>}/></DCArtboard>
  </DCSection>
);

window.HomeArcadeOverhaul = HomeArcadeOverhaul;
