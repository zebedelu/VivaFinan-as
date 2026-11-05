import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach, vi } from 'vitest'

const realFetch = globalThis.fetch

class MemoryStorage {
  constructor() {
    this.map = new Map()
  }

  get length() {
    return this.map.size
  }

  key(index) {
    return Array.from(this.map.keys())[index] ?? null
  }

  getItem(key) {
    return this.map.has(key) ? this.map.get(key) : null
  }

  setItem(key, value) {
    this.map.set(String(key), String(value))
  }

  removeItem(key) {
    this.map.delete(key)
  }

  clear() {
    this.map.clear()
  }
}

// Node 26 exposes an experimental localStorage that shadows jsdom's when no
// --localstorage-file is given. The app only needs a per-test in-memory store.
if (!window.localStorage) {
  Object.defineProperty(window, 'localStorage', {
    value: new MemoryStorage(),
    configurable: true,
  })
}

afterEach(() => {
  cleanup()
  if (realFetch) globalThis.fetch = realFetch
  else delete globalThis.fetch
  try {
    window.localStorage.clear()
  } catch {
    // Ignore storage failures.
  }
  document.documentElement.dataset.theme = 'claro'
  vi.useRealTimers()
})

if (!window.matchMedia) {  window.matchMedia = (query) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })
}

class ResizeObserverStub {
  observe() {}
  unobserve() {}
  disconnect() {}
}

globalThis.ResizeObserver = globalThis.ResizeObserver || ResizeObserverStub
window.ResizeObserver = window.ResizeObserver || ResizeObserverStub
Element.prototype.scrollIntoView = Element.prototype.scrollIntoView || vi.fn()

if (!navigator.clipboard) {
  Object.defineProperty(navigator, 'clipboard', {
    value: { writeText: vi.fn(async () => undefined) },
    configurable: true,
  })
}
