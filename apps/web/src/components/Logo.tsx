/** The mark: Claude A's double ring, as the app draws it beside the notch. */
export function Mark({ size = 20 }: { size?: number }) {
  return (
    <svg width={size - 1} height={size} viewBox="0 0 19 20" aria-hidden="true">
      <circle
        cx="9.5"
        cy="10"
        r="8"
        fill="none"
        stroke="#fff"
        strokeOpacity=".28"
        strokeWidth="2.6"
      />
      <circle
        cx="9.5"
        cy="10"
        r="8"
        fill="none"
        stroke="#fff"
        strokeWidth="2.6"
        strokeLinecap="round"
        strokeDasharray="34 50.3"
        transform="rotate(-90 9.5 10)"
      />
      <circle
        cx="9.5"
        cy="10"
        r="3.6"
        fill="none"
        stroke="#fff"
        strokeOpacity=".22"
        strokeWidth="2"
      />
      <circle
        cx="9.5"
        cy="10"
        r="3.6"
        fill="none"
        stroke="#fff"
        strokeOpacity=".85"
        strokeWidth="2"
        strokeLinecap="round"
        strokeDasharray="14 22.6"
        transform="rotate(-90 9.5 10)"
      />
    </svg>
  )
}

export function Logo() {
  return (
    <a className="logo" href="/" aria-label="Claude Notch home">
      <Mark />
      <span className="logo__word">Claude Notch</span>
    </a>
  )
}
