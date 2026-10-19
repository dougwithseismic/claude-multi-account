/** A tool's inputs in the URL's hash, so a result can be shared. */
export function readHash(): URLSearchParams {
  return new URLSearchParams(window.location.hash.replace(/^#/, ''))
}

/** Replaces the hash without adding a history entry for every keystroke. */
export function writeHash(params: URLSearchParams) {
  const hash = params.toString()
  const url = `${window.location.pathname}${window.location.search}${hash ? `#${hash}` : ''}`
  window.history.replaceState(window.history.state, '', url)
}
