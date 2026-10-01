import { useRef } from 'react'

type RequestState = {
  fingerprint: string
  requestId: string
}

function createRequestId() {
  if (!globalThis.crypto?.randomUUID) {
    throw new Error('Güvenli istek kimliği oluşturulamadı.')
  }

  return globalThis.crypto.randomUUID()
}

export function useIdempotencyRequest() {
  const current = useRef<RequestState | null>(null)

  function getRequestId(payload: unknown) {
    const fingerprint = JSON.stringify(payload)

    if (current.current?.fingerprint === fingerprint) {
      return current.current.requestId
    }

    const requestId = createRequestId()
    current.current = { fingerprint, requestId }
    return requestId
  }

  function clearRequestId() {
    current.current = null
  }

  return { getRequestId, clearRequestId }
}
