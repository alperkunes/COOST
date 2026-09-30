import type {
  SalesAppMapping,
  SalesAppOverview,
} from './salesApp'

export type SalesAppMatchConfidence =
  | 'HIGH'
  | 'MEDIUM'
  | 'LOW'

export type SalesAppMatchSuggestion = {
  menuProductId: string
  menuProductName: string
  score: number
  confidence: SalesAppMatchConfidence
  reason: string
}

function normalize(
  value: string,
) {
  return value
    .toLocaleUpperCase('tr-TR')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/(\d)([A-Z])/g, '$1 $2')
    .replace(/([A-Z])(\d)/g, '$1 $2')
    .replace(/[^A-Z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function parts(
  externalName: string,
) {
  const split =
    externalName
      .split(' / ')
      .map((value) =>
        value.trim(),
      )

  if (split.length < 3) {
    return {
      group: '',
      product:
        externalName.trim(),
      portion: '',
    }
  }

  return {
    group: split[0],
    product: split[1],
    portion: split
      .slice(2)
      .join(' / '),
  }
}

function tokens(
  value: string,
) {
  return normalize(value)
    .split(' ')
    .filter(Boolean)
}

function tokenSimilarity(
  left: string,
  right: string,
) {
  const a =
    new Set(tokens(left))
  const b =
    new Set(tokens(right))

  if (
    !a.size ||
    !b.size
  ) {
    return 0
  }

  let intersection = 0

  for (const token of a) {
    if (b.has(token)) {
      intersection += 1
    }
  }

  const union =
    new Set([
      ...a,
      ...b,
    ]).size

  return intersection / union
}

function bigrams(
  value: string,
) {
  const text =
    normalize(value)
      .replace(/\s/g, '')

  if (!text) return []

  if (text.length === 1) {
    return [text]
  }

  const result: string[] = []

  for (
    let index = 0;
    index <
    text.length - 1;
    index += 1
  ) {
    result.push(
      text.slice(
        index,
        index + 2,
      ),
    )
  }

  return result
}

function diceSimilarity(
  left: string,
  right: string,
) {
  const a =
    bigrams(left)
  const b =
    bigrams(right)

  if (
    !a.length ||
    !b.length
  ) {
    return 0
  }

  const counts =
    new Map<string, number>()

  for (const gram of b) {
    counts.set(
      gram,
      (counts.get(gram) ?? 0) +
        1,
    )
  }

  let matches = 0

  for (const gram of a) {
    const count =
      counts.get(gram) ?? 0

    if (count > 0) {
      matches += 1
      counts.set(
        gram,
        count - 1,
      )
    }
  }

  return (
    (2 * matches) /
    (a.length + b.length)
  )
}

function similarity(
  left: string,
  right: string,
) {
  return (
    diceSimilarity(
      left,
      right,
    ) *
      0.58 +
    tokenSimilarity(
      left,
      right,
    ) *
      0.42
  )
}

function isNormalPortion(
  portion: string,
) {
  const normalized =
    normalize(portion)

  return (
    !normalized ||
    normalized === 'NORMAL' ||
    normalized === 'NORMAL PORSIYON'
  )
}

function candidateNames(
  externalName: string,
) {
  const value =
    parts(externalName)

  const result = [
    value.product,
  ]

  if (
    value.portion &&
    !isNormalPortion(
      value.portion,
    )
  ) {
    result.unshift(
      `${value.product} ${value.portion}`,
    )
  }

  return [
    ...new Set(
      result
        .map(normalize)
        .filter(Boolean),
    ),
  ]
}

export function suggestSalesAppMapping(
  mapping: SalesAppMapping,
  menuProducts: SalesAppOverview['menuProducts'],
): SalesAppMatchSuggestion | null {
  if (
    !mapping.externalProductId.startsWith(
      'NARPOS:',
    )
  ) {
    return null
  }

  const source =
    parts(
      mapping.externalProductName,
    )

  const candidates =
    candidateNames(
      mapping.externalProductName,
    )

  if (!candidates.length) {
    return null
  }

  const ranked =
    menuProducts
      .filter(
        (product) =>
          product.currencyCode ===
          'TRY',
      )
      .map((product) => {
        const target =
          normalize(product.name)

        const score =
          Math.max(
            ...candidates.map(
              (candidate) =>
                similarity(
                  candidate,
                  target,
                ),
            ),
          )

        return {
          product,
          score,
          exact:
            candidates.includes(
              target,
            ),
        }
      })
      .sort(
        (a, b) =>
          b.score -
          a.score,
      )

  const best = ranked[0]

  if (!best) {
    return null
  }

  const second =
    ranked[1]

  const margin =
    best.score -
    (second?.score ?? 0)

  const productOnlyExact =
    normalize(
      source.product,
    ) ===
    normalize(
      best.product.name,
    )

  const portionSensitive =
    !isNormalPortion(
      source.portion,
    )

  let confidence:
    SalesAppMatchConfidence

  let reason: string

  if (
    best.exact &&
    (
      !portionSensitive ||
      !productOnlyExact
    )
  ) {
    confidence = 'HIGH'
    reason =
      portionSensitive
        ? 'Ürün ve porsiyon adı birebir eşleşiyor.'
        : 'Ürün adı birebir eşleşiyor.'
  } else if (
    best.exact &&
    portionSensitive &&
    productOnlyExact
  ) {
    confidence = 'MEDIUM'
    reason =
      'Ürün adı eşleşiyor ancak NarPOS porsiyon bilgisi ayrıca kontrol edilmeli.'
  } else if (
    best.score >= 0.92 &&
    margin >= 0.08
  ) {
    confidence = 'HIGH'
    reason =
      'İsim benzerliği çok yüksek ve alternatiflerden belirgin biçimde ayrılıyor.'
  } else if (
    best.score >= 0.78 &&
    margin >= 0.04
  ) {
    confidence = 'MEDIUM'
    reason =
      'İsim benzerliği güçlü; operatör kontrolü önerilir.'
  } else if (
    best.score >= 0.66 &&
    margin >= 0.02
  ) {
    confidence = 'LOW'
    reason =
      'Olası eşleşme bulundu ancak manuel kontrol gerektiriyor.'
  } else {
    return null
  }

  return {
    menuProductId:
      best.product.id,
    menuProductName:
      best.product.name,
    score:
      Math.round(
        best.score * 100,
      ),
    confidence,
    reason,
  }
}

export function buildSalesAppSuggestions(
  mappings: SalesAppMapping[],
  menuProducts: SalesAppOverview['menuProducts'],
) {
  return new Map(
    mappings.map(
      (mapping) => [
        mapping.id,
        suggestSalesAppMapping(
          mapping,
          menuProducts,
        ),
      ],
    ),
  )
}
