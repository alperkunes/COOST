import {
  useRef,
  useState,
  type FormEvent,
} from 'react'
import { Upload } from 'lucide-react'
import {
  narposBatchKey,
  normalizeNarposProductSalesXlsx,
  type NarposProductSalesImport,
} from '../model/narpos'
import {
  mappingLabels,
  salesAppPreview,
  type SalesAppMapping,
  type SalesAppOverview,
} from '../model/salesApp'
import { costNumber } from '../model/costing'
import { useImportNarposSalesApp } from '../mutations/useSalesAppCommands'
import { Field, Modal } from './CostingDialogs'

export function NarposImportDialog({
  data,
  onClose,
}: {
  data: SalesAppOverview
  onClose: () => void
}) {
  const [locationId, setLocationId] =
    useState('')
  const [file, setFile] =
    useState<NarposProductSalesImport | null>(null)
  const [error, setError] =
    useState('')
  const [reading, setReading] =
    useState(false)
  const [busy, setBusy] =
    useState(false)
  const [confirmed, setConfirmed] =
    useState(false)

  const mutation =
    useImportNarposSalesApp()

  const submitting =
    useRef(false)

  const readVersion =
    useRef(0)

  const preview = file
    ? salesAppPreview(
        file.rows,
        data.mappings,
        locationId,
      )
    : null

  const mismatch =
    preview?.rows.some(
      (row) =>
        row.status === 'MAPPED' &&
        data.menuProducts.find(
          (product) =>
            product.id ===
            row.menuProductId,
        )?.currencyCode !==
          file?.currencyCode,
    ) ?? false

  async function readFile(
    selected?: File,
  ) {
    const version =
      ++readVersion.current

    setFile(null)
    setError('')
    setConfirmed(false)

    if (!selected) {
      setReading(false)
      return
    }

    if (
      !selected.name
        .toLowerCase()
        .endsWith('.xlsx')
    ) {
      setError(
        'NarPOS Ürün Satışları raporu XLSX formatında olmalıdır.',
      )
      return
    }

    if (
      selected.size >
      5 * 1024 * 1024
    ) {
      setError(
        'Dosya en fazla 5 MB olabilir.',
      )
      return
    }

    setReading(true)

    try {
      const parsed =
        await normalizeNarposProductSalesXlsx(
          await selected.arrayBuffer(),
          selected.name,
        )

      if (
        version ===
        readVersion.current
      ) {
        setFile(parsed)
      }
    } catch (cause) {
      if (
        version ===
        readVersion.current
      ) {
        setError(
          cause instanceof Error
            ? cause.message
            : 'NarPOS dosyası okunamadı.',
        )
      }
    } finally {
      if (
        version ===
        readVersion.current
      ) {
        setReading(false)
      }
    }
  }

  const valid =
    !!file &&
    !!locationId &&
    confirmed &&
    !mismatch &&
    !reading

  async function submit(
    event: FormEvent,
  ) {
    event.preventDefault()

    if (
      !valid ||
      !file ||
      submitting.current ||
      busy
    ) {
      return
    }

    submitting.current = true
    setBusy(true)
    setError('')

    try {
      const input = {
        locationId,
        businessDate:
          file.businessDate,
        currencyCode:
          file.currencyCode,
        rows: file.rows,
      }

      await mutation.mutateAsync({
        ...input,
        externalBatchKey:
          await narposBatchKey(
            input,
          ),
      })

      onClose()
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : 'NarPOS içe aktarımı tamamlanamadı.',
      )
    } finally {
      submitting.current = false
      setBusy(false)
    }
  }

  return (
    <Modal
      title="NarPOS Excel İçe Aktar"
      busy={busy || reading}
      onClose={onClose}
    >
      <form onSubmit={submit}>
        <fieldset
          className="costing-fields"
          disabled={busy || reading}
        >
          <Field label="Lokasyon">
            <select
              value={locationId}
              onChange={(event) => {
                setLocationId(
                  event.target.value,
                )
                setConfirmed(false)
              }}
            >
              <option value="">
                Seçin
              </option>

              {data.locations.map(
                (location) => (
                  <option
                    key={location.id}
                    value={location.id}
                  >
                    {location.name}
                  </option>
                ),
              )}
            </select>
          </Field>

          <Field label="NarPOS Ürün Satışları XLSX">
            <input
              type="file"
              accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              onChange={(event) => {
                void readFile(
                  event.target
                    .files?.[0],
                )
              }}
            />
          </Field>
        </fieldset>

        {reading ? (
          <p role="status">
            NarPOS dosyası okunuyor...
          </p>
        ) : null}

        {file && preview ? (
          <>
            <dl className="costing-totals">
              <div>
                <dt>İş Günü</dt>
                <dd>
                  {file.businessDate}
                </dd>
              </div>

              <div>
                <dt>Satır</dt>
                <dd>
                  {preview.rows.length}
                </dd>
              </div>

              <div>
                <dt>Toplam Adet</dt>
                <dd>
                  {costNumber(
                    file.quantityTotal,
                    4,
                  )}
                </dd>
              </div>

              <div>
                <dt>
                  KDV Dahil Satış
                </dt>
                <dd>
                  {costNumber(
                    file.grossSalesTotal,
                  )}{' '}
                  TRY
                </dd>
              </div>

              {Object.entries(
                preview.counts,
              ).map(
                ([key, value]) => (
                  <div key={key}>
                    <dt>
                      {
                        mappingLabels[
                          key as SalesAppMapping['status']
                        ]
                      }
                    </dt>
                    <dd>{value}</dd>
                  </div>
                ),
              )}
            </dl>

            {file.roundingAdjustmentCents !==
            0 ? (
              <p>
                NarPOS kuruş
                mutabakatı:{' '}
                {file.roundingAdjustmentCents >
                0
                  ? '+'
                  : ''}
                {
                  file.roundingAdjustmentCents
                }{' '}
                kuruş. Günlük toplam
                korunmuştur.
              </p>
            ) : null}

            <div className="costing-table-wrap sales-app-preview">
              <table>
                <thead>
                  <tr>
                    <th>Ürün</th>
                    <th>Adet</th>
                    <th>
                      KDV Dahil Satış
                    </th>
                    <th>Durum</th>
                  </tr>
                </thead>

                <tbody>
                  {preview.rows
                    .slice(0, 100)
                    .map((row) => (
                      <tr
                        key={
                          row.externalProductId
                        }
                      >
                        <th scope="row">
                          {
                            row.externalProductName
                          }
                        </th>
                        <td>
                          {costNumber(
                            row.quantity,
                            4,
                          )}
                        </td>
                        <td>
                          {costNumber(
                            row.grossSales,
                          )}
                        </td>
                        <td>
                          {
                            mappingLabels[
                              row.status
                            ]
                          }
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
            </div>

            {preview.rows.length >
            100 ? (
              <p>
                İlk 100 satır
                gösteriliyor.
              </p>
            ) : null}

            <p className="costing-warning">
              NarPOS “Toplam Tutar”
              değeri KDV dahil
              gerçekleşmiş satış
              olarak aktarılır.
              COOST, eşleştirilen
              menü ürününün KDV
              oranını kullanarak KDV
              hariç satış tutarını
              hesaplar. Bu dosya
              seçilen lokasyon ve iş
              günü için tam günlük
              Satış Uygulaması verisi
              kabul edilir.
            </p>

            <label className="sales-app-confirm">
              <input
                type="checkbox"
                disabled={busy}
                checked={confirmed}
                onChange={(event) =>
                  setConfirmed(
                    event.target
                      .checked,
                  )
                }
              />
              NarPOS günlük satış
              verisinin aktarılmasını
              onaylıyorum.
            </label>
          </>
        ) : null}

        {mismatch ? (
          <p role="alert">
            Eşleştirilen menü ürünü
            ile NarPOS para birimi
            aynı olmalıdır.
          </p>
        ) : null}

        {error ? (
          <p role="alert">
            {error}
          </p>
        ) : null}

        <button
          type="submit"
          disabled={!valid || busy}
        >
          <Upload size={16} />
          {busy
            ? 'NarPOS Aktarılıyor...'
            : 'NarPOS İçe Aktarımı Onayla'}
        </button>
      </form>
    </Modal>
  )
}
