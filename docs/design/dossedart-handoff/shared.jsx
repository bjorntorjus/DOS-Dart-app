// Shared helpers used across all variation files.
// Annotation = sketchy red callout used to mark up the "current" screens.
// Place an annotation at top/left in PARENT-relative coords. Width default 160.
const Annotation = ({ top, left, width = 160, children }) => (
  <div
    style={{
      position: 'absolute',
      top,
      left,
      width,
      fontFamily: "'Architects Daughter', cursive",
      color: '#d94234',
      fontSize: 13,
      lineHeight: 1.25,
      zIndex: 5,
      pointerEvents: 'none',
    }}
  >
    <div
      style={{
        borderLeft: '2px solid #d94234',
        paddingLeft: 6,
      }}
    >
      {children}
    </div>
  </div>
);

window.Annotation = Annotation;
