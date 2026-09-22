import { describe, expect, it } from 'vitest'

describe('COOST foundation', () => {
  it('runs with the browser test environment', () => {
    expect(document.body).toBeInTheDocument()
  })
})