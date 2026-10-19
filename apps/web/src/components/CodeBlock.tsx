import { useEffect, useRef, useState } from 'react'

/** Copies `text`, and says so on the button for a moment. */
export function useCopy() {
  const [state, setState] = useState<'idle' | 'copied' | 'failed'>('idle')
  const timer = useRef<number>(undefined)
  useEffect(() => () => window.clearTimeout(timer.current), [])
  const copy = (text: string) =>
    navigator.clipboard?.writeText(text).then(
      () => {
        setState('copied')
        window.clearTimeout(timer.current)
        timer.current = window.setTimeout(() => setState('idle'), 1600)
      },
      () => setState('failed'),
    )
  return { state, copy }
}

/** A code block like the Markdown pages', for text a page builds. */
export function CodeBlock({ code, lang }: { code: string; lang: 'bash' | 'json' }) {
  const { state, copy } = useCopy()
  return (
    <div className="code" data-lang={lang}>
      <pre>
        <code>{code}</code>
      </pre>
      <button
        type="button"
        className="code__copy"
        data-copied={state === 'copied' ? '' : undefined}
        onClick={() => copy(code)}
      >
        {state === 'copied' ? 'Copied' : state === 'failed' ? 'Select and copy' : 'Copy'}
      </button>
    </div>
  )
}
