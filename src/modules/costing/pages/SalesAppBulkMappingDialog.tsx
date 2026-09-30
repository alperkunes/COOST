import {
  useMemo,
  useRef,
  useState,
  type FormEvent,
} from 'react'
import { Link } from 'lucide-react'
import {
  mappingLabels,
  type SalesAppMapping,
  type SalesAppOverview,
} from '../model/salesApp'
import {
  buildSalesAppSuggestions,
} from '../model/salesAppMatching'
import {
  useBulkUpdateSalesAppMappings,
  type BulkSalesAppMappingUpdate,
} from '../mutations/useSalesAppCommands'
import { Field, Modal } from './CostingDialogs'

const IGNORED_VALUE = '__IGNORED__'

function currentValue(
  mapping: SalesAppMapping,
) {
  if (
    mapping.status === 'MAPPED' &&
    mapping.menuProductId
  ) {
    return mapping.menuProductId
  }

  if (mapping.status === 'IGNORED') {
    return IGNORED_VALUE
  }

  return ''
}

function displayParts(
  name: string,
) {
  const parts = name.split(' / ')

  if (parts.length < 3) {
    return {
      group: '',
      product: name,
      portion: '',
    }
  }

  return {
    group: parts[0],
    product: parts[1],
    portion: parts
      .slice(2)
      .join(' / '),
  }
}

export function SalesAppBulkMappingDialog({
  data,
  onClose,
}: {
  data: SalesAppOverview
  onClose: () => void
}) {
  const narposMappings = useMemo(
    () =>
      data.mappings
        .filter((mapping) =>
          mapping.externalProductId.startsWith(
            'NARPOS:',
          ),
        )
        .sort((a, b) =>
          a.externalProductName.localeCompare(
            b.externalProductName,
            'tr',
          ),
        ),
    [data.mappings],
  )

  const menuProducts = useMemo(
    () =>
      [...data.menuProducts].sort(
        (a, b) =>
          a.name.localeCompare(
            b.name,
            'tr',
          ),
      ),
    [data.menuProducts],
  )

  const suggestions = useMemo(
    () =>
      buildSalesAppSuggestions(
        narposMappings,
        menuProducts,
      ),
    [
      narposMappings,
      menuProducts,
    ],
  )

  const [values, setValues] =
    useState<Record<string, string>>(
      () =>
        Object.fromEntries(
          narposMappings.map(
            (mapping) => {
              const suggestion =
                suggestions.get(
                  mapping.id,
                )

              const value =
                mapping.status ===
                  'UNMAPPED' &&
                suggestion?.confidence ===
                  'HIGH'
                  ? suggestion
                      .menuProductId
                  : currentValue(
                      mapping,
                    )

              return [
                mapping.id,
                value,
              ]
            },
          ),
        ),
    )

  const [search, setSearch] =
    useState('')

  const [
    onlyInitiallyUnmapped,
    setOnlyInitiallyUnmapped,
  ] = useState(true)

  const mutation =
    useBulkUpdateSalesAppMappings()

  const submitting =
    useRef(false)

  const updates =
    useMemo<
      BulkSalesAppMappingUpdate[]
    >(() => {
      const result:
        BulkSalesAppMappingUpdate[] =
        []

      for (
        const mapping of
        narposMappings
      ) {
        const before =
          currentValue(mapping)

        const after =
          values[mapping.id] ??
          before

        if (before === after) {
          continue
        }

        if (after === '') {
          result.push({
            mappingId:
              mapping.id,
            status: 'UNMAPPED',
            menuProductId: null,
          })

          continue
        }

        if (
          after === IGNORED_VALUE
        ) {
          result.push({
            mappingId:
              mapping.id,
            status: 'IGNORED',
            menuProductId: null,
          })

          continue
        }

        result.push({
          mappingId:
            mapping.id,
          status: 'MAPPED',
          menuProductId: after,
        })
      }

      return result
    }, [
      narposMappings,
      values,
    ])

  const filtered =
    useMemo(() => {
      const term = search
        .trim()
        .toLocaleUpperCase(
          'tr-TR',
        )

      return narposMappings.filter(
        (mapping) => {
          if (
            onlyInitiallyUnmapped &&
            mapping.status !==
              'UNMAPPED'
          ) {
            return false
          }

          if (!term) {
            return true
          }

          return [
            mapping.externalProductName,
            mapping.menuProductName ??
              '',
          ]
            .join(' ')
            .toLocaleUpperCase(
              'tr-TR',
            )
            .includes(term)
        },
      )
    }, [
      narposMappings,
      onlyInitiallyUnmapped,
      search,
    ])

  const highSuggestionCount =
    useMemo(
      () =>
        narposMappings.filter(
          (mapping) =>
            mapping.status ===
              'UNMAPPED' &&
            suggestions.get(
              mapping.id,
            )?.confidence ===
              'HIGH',
        ).length,
      [
        narposMappings,
        suggestions,
      ],
    )

  const draftCounts =
    useMemo(() => {
      const result = {
        MAPPED: 0,
        UNMAPPED: 0,
        IGNORED: 0,
      }

      for (
        const mapping of
        narposMappings
      ) {
        const value =
          values[mapping.id] ??
          currentValue(mapping)

        if (
          value ===
          IGNORED_VALUE
        ) {
          result.IGNORED += 1
        } else if (value) {
          result.MAPPED += 1
        } else {
          result.UNMAPPED += 1
        }
      }

      return result
    }, [
      narposMappings,
      values,
    ])

  async function submit(
    event: FormEvent,
  ) {
    event.preventDefault()

    if (
      !updates.length ||
      mutation.isPending ||
      submitting.current
    ) {
      return
    }

    submitting.current = true

    try {
      await mutation.mutateAsync(
        updates,
      )

      onClose()
    } catch {
      // Preserve selections for retry.
    } finally {
      submitting.current = false
    }
  }

  return (
    <Modal
      title="NarPOS Toplu Ürün Eşleştirme"
      busy={mutation.isPending}
      onClose={onClose}
    >
      <form
        className="sales-app-bulk-form"
        onSubmit={submit}
      >
        <p>
          NarPOS ürünlerini COOST
          menü ürünleriyle burada
          topluca eşleştirebilirsin.
          Tüm değişiklikler tek
          işlemde kaydedilir; bir
          satır başarısız olursa
          hiçbir değişiklik
          uygulanmaz.
        </p>

        <div className="sales-app-bulk-toolbar">
          <Field label="NarPOS ürünlerinde ara">
            <input
              type="search"
              value={search}
              placeholder="Ürün, grup veya porsiyon..."
              disabled={
                mutation.isPending
              }
              onChange={(event) =>
                setSearch(
                  event.target.value,
                )
              }
            />
          </Field>

          <label className="sales-app-bulk-filter">
            <input
              type="checkbox"
              checked={
                onlyInitiallyUnmapped
              }
              disabled={
                mutation.isPending
              }
              onChange={(event) =>
                setOnlyInitiallyUnmapped(
                  event.target
                    .checked,
                )
              }
            />
            Sadece henüz
            eşleştirilmemiş ürünler
          </label>
        </div>

        <dl className="costing-totals">
          <div>
            <dt>
              NarPOS Ürünü
            </dt>
            <dd>
              {
                narposMappings.length
              }
            </dd>
          </div>

          <div>
            <dt>
              Eşleştirilecek
            </dt>
            <dd>
              {draftCounts.MAPPED}
            </dd>
          </div>

          <div>
            <dt>
              Eşleştirilmemiş
            </dt>
            <dd>
              {
                draftCounts.UNMAPPED
              }
            </dd>
          </div>

          <div>
            <dt>
              Hariç Tutulacak
            </dt>
            <dd>
              {draftCounts.IGNORED}
            </dd>
          </div>

          <div>
            <dt>
              Otomatik Yüksek Güven
            </dt>
            <dd>
              {
                highSuggestionCount
              }
            </dd>
          </div>

          <div>
            <dt>
              Bekleyen Değişiklik
            </dt>
            <dd>
              {updates.length}
            </dd>
          </div>

          <div>
            <dt>
              Görünen Satır
            </dt>
            <dd>
              {filtered.length}
            </dd>
          </div>
        </dl>

        <div className="costing-table-wrap sales-app-bulk-table">
          <table>
            <thead>
              <tr>
                <th>
                  NarPOS Ürünü
                </th>
                <th>
                  Mevcut Durum
                </th>
                <th>
                  COOST Eşleştirmesi
                </th>
              </tr>
            </thead>

            <tbody>
              {filtered.map(
                (mapping) => {
                  const parts =
                    displayParts(
                      mapping.externalProductName,
                    )

                  const value =
                    values[
                      mapping.id
                    ] ??
                    currentValue(
                      mapping,
                    )

                  const suggestion =
                    suggestions.get(
                      mapping.id,
                    )

                  return (
                    <tr
                      key={
                        mapping.id
                      }
                    >
                      <th scope="row">
                        {
                          parts.product
                        }

                        <small>
                          {[
                            parts.group,
                            parts.portion,
                          ]
                            .filter(
                              Boolean,
                            )
                            .join(
                              ' · ',
                            )}
                        </small>
                      </th>

                      <td>
                        {
                          mappingLabels[
                            mapping
                              .status
                          ]
                        }

                        {mapping.menuProductName ? (
                          <small>
                            {
                              mapping.menuProductName
                            }
                          </small>
                        ) : null}
                      </td>

                      <td>
                        <select
                          aria-label={`${mapping.externalProductName} COOST eşleştirmesi`}
                          value={
                            value
                          }
                          disabled={
                            mutation.isPending
                          }
                          onChange={(
                            event,
                          ) =>
                            setValues(
                              (
                                current,
                              ) => ({
                                ...current,
                                [mapping.id]:
                                  event
                                    .target
                                    .value,
                              }),
                            )
                          }
                        >
                          <option value="">
                            Eşleştirilmedi
                          </option>

                          <option
                            value={
                              IGNORED_VALUE
                            }
                          >
                            Hariç Tut
                          </option>

                          <optgroup label="COOST Menü Ürünleri">
                            {menuProducts.map(
                              (
                                product,
                              ) => (
                                <option
                                  key={
                                    product.id
                                  }
                                  value={
                                    product.id
                                  }
                                  disabled={
                                    product.currencyCode !==
                                    'TRY'
                                  }
                                >
                                  {
                                    product.name
                                  }{' '}
                                  ·{' '}
                                  {
                                    product.currencyCode
                                  }
                                </option>
                              ),
                            )}
                          </optgroup>
                        </select>

                        {suggestion ? (
                          <small
                            className={`sales-app-match-suggestion sales-app-match-${suggestion.confidence.toLowerCase()}`}
                          >
                            Öneri:{' '}
                            {
                              suggestion.menuProductName
                            }{' '}
                            · %{suggestion.score}{' '}
                            ·{' '}
                            {suggestion.confidence ===
                            'HIGH'
                              ? 'Yüksek güven'
                              : suggestion.confidence ===
                                  'MEDIUM'
                                ? 'Orta güven'
                                : 'Düşük güven'}
                            <span>
                              {
                                suggestion.reason
                              }
                            </span>
                          </small>
                        ) : (
                          <small className="sales-app-match-none">
                            Güvenilir otomatik
                            öneri bulunamadı.
                          </small>
                        )}
                      </td>
                    </tr>
                  )
                },
              )}

              {!filtered.length ? (
                <tr>
                  <td colSpan={3}>
                    Bu filtreye uygun
                    NarPOS ürünü yok.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>

        {highSuggestionCount > 0 ? (
          <p className="sales-app-match-info">
            Sistem{' '}
            <strong>
              {highSuggestionCount}
            </strong>{' '}
            yüksek güvenli eşleşmeyi
            otomatik olarak taslağa
            seçti. Bunlar henüz
            kaydedilmedi; aşağıdaki
            seçenekleri kontrol edip
            toplu kaydetme işlemini
            sen başlatacaksın.
          </p>
        ) : null}

        <p className="costing-warning">
          Eşleştirmeleri kaydetmek
          geçmiş satış rakamlarını
          hemen değiştirmez.
          Eşleştirmeler tamamlandıktan
          sonra 29 Eylül içe
          aktarımını “Yeniden İşle”
          komutuyla çalıştıracağız.
          Böylece KDV hariç satış ve
          kârlılık hesapları yeni
          eşleştirmeler üzerinden
          oluşturulur.
        </p>

        {mutation.isError ? (
          <p
            role="alert"
            className="finance-dialog-error"
          >
            {
              mutation.error
                .message
            }
          </p>
        ) : null}

        <div className="finance-dialog-actions">
          <button
            type="button"
            disabled={
              mutation.isPending
            }
            onClick={onClose}
          >
            Vazgeç
          </button>

          <button
            type="submit"
            className="primary"
            disabled={
              !updates.length ||
              mutation.isPending
            }
          >
            <Link size={16} />
            {mutation.isPending
              ? 'Kaydediliyor...'
              : `${updates.length} Değişikliği Kaydet`}
          </button>
        </div>
      </form>
    </Modal>
  )
}
