import {
  useMemo,
  useState,
  type FormEvent,
} from 'react'
import {
  Pencil,
  Plus,
  RefreshCw,
  RotateCw,
} from 'lucide-react'

import {
  useCreateSalesAppConnection,
  useRunSalesAppSync,
  useUpdateSalesAppConnection,
} from '../mutations/useSalesAppSyncCommands'
import {
  salesAppConnectionCreateSchema,
  salesAppConnectionUpdateSchema,
  salesAppSyncRequestSchema,
  salesAppSyncStatusLabel,
  type SalesAppConnection,
  type SalesAppConnectionStatus,
} from '../model/salesAppSync'
import { useSalesAppSync } from '../queries/useSalesAppSync'
import {
  Field,
  Modal,
} from './CostingDialogs'

function localToday() {
  const now = new Date()

  const local = new Date(
    now.getTime() -
      now.getTimezoneOffset() * 60_000,
  )

  return local.toISOString().slice(0, 10)
}

type ConnectionDialog =
  | { kind: 'create' }
  | {
      kind: 'edit'
      connection: SalesAppConnection
    }
  | null

function CreateConnectionDialog({
  locations,
  onClose,
}: {
  locations: Array<{
    id: string
    name: string
  }>
  onClose: () => void
}) {
  const mutation =
    useCreateSalesAppConnection()

  const [locationId, setLocationId] =
    useState('')
  const [adapterKey, setAdapterKey] =
    useState('')
  const [
    externalLocationId,
    setExternalLocationId,
  ] = useState('')
  const [
    syncLookbackDays,
    setSyncLookbackDays,
  ] = useState(1)

  const input = {
    locationId,
    adapterKey,
    externalLocationId,
    syncLookbackDays,
  }

  const valid =
    salesAppConnectionCreateSchema.safeParse(
      input,
    ).success

  async function submit(
    event: FormEvent,
  ) {
    event.preventDefault()

    if (
      !valid ||
      mutation.isPending
    ) {
      return
    }

    try {
      await mutation.mutateAsync(input)
      onClose()
    } catch {
      // Form değerlerini düzeltme/tekrar deneme için koru.
    }
  }

  return (
    <Modal
      title="Satış Uygulaması Bağlantısı Oluştur"
      busy={mutation.isPending}
      onClose={onClose}
    >
      <form onSubmit={submit}>
        <fieldset
          className="costing-fields"
          disabled={mutation.isPending}
        >
          <Field label="Lokasyon">
            <select
              value={locationId}
              onChange={(event) =>
                setLocationId(
                  event.target.value,
                )
              }
            >
              <option value="">
                Seçin
              </option>

              {locations.map(
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

          <Field label="Adaptör Anahtarı">
            <input
              value={adapterKey}
              maxLength={64}
              autoComplete="off"
              placeholder="Sağlayıcı adaptörü hazır olduğunda"
              onChange={(event) =>
                setAdapterKey(
                  event.target.value,
                )
              }
            />
          </Field>

          <Field label="Harici Lokasyon Kimliği">
            <input
              value={externalLocationId}
              maxLength={200}
              autoComplete="off"
              onChange={(event) =>
                setExternalLocationId(
                  event.target.value,
                )
              }
            />
          </Field>

          <Field label="Geriye Dönük Gün">
            <input
              type="number"
              min={1}
              max={31}
              step={1}
              value={syncLookbackDays}
              onChange={(event) =>
                setSyncLookbackDays(
                  Number(
                    event.target.value,
                  ),
                )
              }
            />
          </Field>
        </fieldset>

        <p>
          Bağlantı önce Taslak olarak
          oluşturulur. Aktif hale getirmek
          için geçerli adaptör ve harici
          lokasyon bilgisi gerekir.
        </p>

        {mutation.isError ? (
          <p role="alert">
            {mutation.error.message}
          </p>
        ) : null}

        <div className="finance-dialog-actions">
          <button
            type="button"
            disabled={mutation.isPending}
            onClick={onClose}
          >
            Vazgeç
          </button>

          <button
            type="submit"
            className="primary"
            disabled={
              !valid ||
              mutation.isPending
            }
          >
            <Plus size={16} />
            Bağlantı Oluştur
          </button>
        </div>
      </form>
    </Modal>
  )
}

function EditConnectionDialog({
  connection,
  onClose,
}: {
  connection: SalesAppConnection
  onClose: () => void
}) {
  const mutation =
    useUpdateSalesAppConnection()

  const [adapterKey, setAdapterKey] =
    useState(
      connection.adapterKey ?? '',
    )

  const [
    externalLocationId,
    setExternalLocationId,
  ] = useState(
    connection.externalLocationId ?? '',
  )

  const [status, setStatus] =
    useState<SalesAppConnectionStatus>(
      connection.status,
    )

  const [
    syncLookbackDays,
    setSyncLookbackDays,
  ] = useState(
    connection.syncLookbackDays,
  )

  const input = {
    connectionId: connection.id,
    adapterKey,
    externalLocationId,
    status,
    syncEnabled:
      status === 'ACTIVE'
        ? connection.syncEnabled
        : false,
    syncLookbackDays,
  }

  const valid =
    salesAppConnectionUpdateSchema.safeParse(
      input,
    ).success

  async function submit(
    event: FormEvent,
  ) {
    event.preventDefault()

    if (
      !valid ||
      mutation.isPending
    ) {
      return
    }

    try {
      await mutation.mutateAsync(input)
      onClose()
    } catch {
      // Form değerlerini düzeltme/tekrar deneme için koru.
    }
  }

  return (
    <Modal
      title="Satış Uygulaması Bağlantısını Düzenle"
      busy={mutation.isPending}
      onClose={onClose}
    >
      <form onSubmit={submit}>
        <p>
          Lokasyon: {connection.locationName}
        </p>

        <fieldset
          className="costing-fields"
          disabled={mutation.isPending}
        >
          <Field label="Adaptör Anahtarı">
            <input
              value={adapterKey}
              maxLength={64}
              autoComplete="off"
              onChange={(event) =>
                setAdapterKey(
                  event.target.value,
                )
              }
            />
          </Field>

          <Field label="Harici Lokasyon Kimliği">
            <input
              value={externalLocationId}
              maxLength={200}
              autoComplete="off"
              onChange={(event) =>
                setExternalLocationId(
                  event.target.value,
                )
              }
            />
          </Field>

          <Field label="Durum">
            <select
              value={status}
              onChange={(event) =>
                setStatus(
                  event.target.value as
                    SalesAppConnectionStatus,
                )
              }
            >
              <option value="DRAFT">
                Taslak
              </option>
              <option value="ACTIVE">
                Aktif
              </option>
              <option value="PAUSED">
                Duraklatıldı
              </option>
            </select>
          </Field>

          <Field label="Geriye Dönük Gün">
            <input
              type="number"
              min={1}
              max={31}
              step={1}
              value={syncLookbackDays}
              onChange={(event) =>
                setSyncLookbackDays(
                  Number(
                    event.target.value,
                  ),
                )
              }
            />
          </Field>
        </fieldset>

        <p>
          Zamanlanmış otomatik
          senkronizasyon henüz devrede
          değildir. Mevcut otomatik sync
          ayarı korunur; bu ekrandan
          değiştirilmez.
        </p>

        {mutation.isError ? (
          <p role="alert">
            {mutation.error.message}
          </p>
        ) : null}

        <div className="finance-dialog-actions">
          <button
            type="button"
            disabled={mutation.isPending}
            onClick={onClose}
          >
            Vazgeç
          </button>

          <button
            type="submit"
            className="primary"
            disabled={
              !valid ||
              mutation.isPending
            }
          >
            Kaydet
          </button>
        </div>
      </form>
    </Modal>
  )
}

export function SalesAppSyncSection({
  canWrite,
}: {
  canWrite: boolean
}) {
  const query = useSalesAppSync()
  const mutation = useRunSalesAppSync()

  const [dialog, setDialog] =
    useState<ConnectionDialog>(null)

  const today = useMemo(
    () => localToday(),
    [],
  )

  const [connectionId, setConnectionId] =
    useState('')

  const [
    businessDateStart,
    setBusinessDateStart,
  ] = useState(today)

  const [
    businessDateEnd,
    setBusinessDateEnd,
  ] = useState(today)

  const activeConnections =
    query.data?.connections.filter(
      (connection) =>
        connection.status === 'ACTIVE',
    ) ?? []

  const unusedLocations =
    query.data?.locations.filter(
      (location) =>
        !query.data?.connections.some(
          (connection) =>
            connection.locationId ===
            location.id,
        ),
    ) ?? []

  const hasActiveRun =
    query.data?.recentRuns.some(
      (run) =>
        run.connectionId ===
          connectionId &&
        (
          run.status === 'QUEUED' ||
          run.status === 'RUNNING'
        ),
    ) ?? false

  const syncInput = {
    connectionId,
    businessDateStart,
    businessDateEnd,
  }

  const syncValid =
    salesAppSyncRequestSchema.safeParse(
      syncInput,
    ).success

  async function submitSync(
    event: FormEvent,
  ) {
    event.preventDefault()

    if (
      !syncValid ||
      mutation.isPending ||
      hasActiveRun
    ) {
      return
    }

    try {
      await mutation.mutateAsync(
        syncInput,
      )
    } catch {
      // Seçimleri tekrar deneme için koru.
    }
  }

  return (
    <section
      className="sales-app-sync-section"
      aria-label="Satış Uygulaması senkronizasyonu"
    >
      <div className="costing-record-heading">
        <h3>Senkronizasyon</h3>

        <button
          type="button"
          title="Senkronizasyon durumunu yenile"
          aria-label="Senkronizasyon durumunu yenile"
          disabled={query.isFetching}
          onClick={() => {
            void query.refetch()
          }}
        >
          <RefreshCw size={16} />
        </button>

        {canWrite &&
        unusedLocations.length ? (
          <button
            type="button"
            onClick={() =>
              setDialog({
                kind: 'create',
              })
            }
          >
            <Plus size={16} />
            Yeni Bağlantı
          </button>
        ) : null}
      </div>

      {query.isPending ? (
        <p role="status">
          Senkronizasyon bilgileri
          yükleniyor...
        </p>
      ) : query.isError ? (
        <p role="alert">
          {query.error.message}
        </p>
      ) : query.data ? (
        <>
          <h4>Bağlantılar</h4>

          <div className="costing-table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Lokasyon</th>
                  <th>Durum</th>
                  <th>Adaptör</th>
                  <th>Harici Lokasyon</th>
                  <th>Geriye Dönük Gün</th>
                  <th>Otomatik Sync</th>
                  <th />
                </tr>
              </thead>

              <tbody>
                {query.data.connections.map(
                  (connection) => (
                    <tr key={connection.id}>
                      <th scope="row">
                        {connection.locationName}
                      </th>

                      <td>
                        {connection.status ===
                        'ACTIVE'
                          ? 'Aktif'
                          : connection.status ===
                              'PAUSED'
                            ? 'Duraklatıldı'
                            : 'Taslak'}
                      </td>

                      <td>
                        {connection.adapterKey ??
                          'Yapılandırılmadı'}
                      </td>

                      <td>
                        {connection.externalLocationId ??
                          '—'}
                      </td>

                      <td>
                        {
                          connection.syncLookbackDays
                        }
                      </td>

                      <td>
                        {connection.syncEnabled
                          ? 'Açık'
                          : 'Kapalı'}
                      </td>

                      <td>
                        {canWrite ? (
                          <button
                            type="button"
                            title="Bağlantıyı düzenle"
                            aria-label={`${connection.locationName} bağlantısını düzenle`}
                            onClick={() =>
                              setDialog({
                                kind: 'edit',
                                connection,
                              })
                            }
                          >
                            <Pencil size={16} />
                            Düzenle
                          </button>
                        ) : null}
                      </td>
                    </tr>
                  ),
                )}

                {!query.data.connections.length ? (
                  <tr>
                    <td colSpan={7}>
                      Henüz Satış Uygulaması
                      bağlantısı bulunmuyor.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>

          {canWrite ? (
            <>
              <h4>Şimdi Senkronize Et</h4>

              <form onSubmit={submitSync}>
                <fieldset
                  className="costing-fields"
                  disabled={mutation.isPending}
                >
                  <Field label="Bağlantı">
                    <select
                      value={connectionId}
                      onChange={(event) =>
                        setConnectionId(
                          event.target.value,
                        )
                      }
                    >
                      <option value="">
                        Seçin
                      </option>

                      {activeConnections.map(
                        (connection) => (
                          <option
                            key={connection.id}
                            value={connection.id}
                          >
                            {
                              connection.locationName
                            }
                          </option>
                        ),
                      )}
                    </select>
                  </Field>

                  <Field label="Başlangıç Tarihi">
                    <input
                      type="date"
                      value={businessDateStart}
                      onChange={(event) =>
                        setBusinessDateStart(
                          event.target.value,
                        )
                      }
                    />
                  </Field>

                  <Field label="Bitiş Tarihi">
                    <input
                      type="date"
                      value={businessDateEnd}
                      onChange={(event) =>
                        setBusinessDateEnd(
                          event.target.value,
                        )
                      }
                    />
                  </Field>
                </fieldset>

                {!activeConnections.length ? (
                  <p className="costing-warning">
                    Manuel senkronizasyon için
                    aktif ve yapılandırılmış bir
                    bağlantı gereklidir.
                  </p>
                ) : null}

                {hasActiveRun ? (
                  <p role="status">
                    Bu bağlantı için devam eden
                    bir senkronizasyon bulunuyor.
                  </p>
                ) : null}

                {mutation.isError ? (
                  <p role="alert">
                    {mutation.error.message}
                  </p>
                ) : null}

                {mutation.isSuccess ? (
                  <p role="status">
                    Senkronizasyon tamamlandı.{' '}
                    {
                      mutation.data
                        .importedRowCount
                    }{' '}
                    satış satırı aktarıldı.
                  </p>
                ) : null}

                <button
                  type="submit"
                  disabled={
                    !syncValid ||
                    mutation.isPending ||
                    hasActiveRun
                  }
                >
                  <RotateCw size={16} />

                  {mutation.isPending
                    ? 'Senkronize ediliyor...'
                    : 'Şimdi Senkronize Et'}
                </button>
              </form>
            </>
          ) : null}

          <h4>Senkronizasyon Geçmişi</h4>

          <div className="costing-table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Lokasyon</th>
                  <th>Dönem</th>
                  <th>Tetikleme</th>
                  <th>Durum</th>
                  <th>Aktarılan Gün</th>
                  <th>Satır</th>
                  <th>Başlangıç</th>
                  <th>Bitiş</th>
                  <th>Hata</th>
                </tr>
              </thead>

              <tbody>
                {query.data.recentRuns.map(
                  (run) => (
                    <tr key={run.id}>
                      <th scope="row">
                        {run.locationName}
                      </th>

                      <td>
                        {run.businessDateStart}
                        {run.businessDateStart !==
                        run.businessDateEnd
                          ? ` → ${run.businessDateEnd}`
                          : ''}
                      </td>

                      <td>
                        {run.triggerType ===
                        'MANUAL'
                          ? 'Manuel'
                          : run.triggerType ===
                              'SCHEDULED'
                            ? 'Zamanlanmış'
                            : 'Tekrar'}
                      </td>

                      <td>
                        {salesAppSyncStatusLabel(
                          run.status,
                        )}
                      </td>

                      <td>
                        {run.importBatchCount}
                      </td>

                      <td>
                        {run.importedRowCount}
                      </td>

                      <td>
                        {run.startedAt
                          ? new Date(
                              run.startedAt,
                            ).toLocaleString(
                              'tr-TR',
                            )
                          : '—'}
                      </td>

                      <td>
                        {run.finishedAt
                          ? new Date(
                              run.finishedAt,
                            ).toLocaleString(
                              'tr-TR',
                            )
                          : '—'}
                      </td>

                      <td>
                        {run.errorMessage ??
                          '—'}
                      </td>
                    </tr>
                  ),
                )}

                {!query.data.recentRuns.length ? (
                  <tr>
                    <td colSpan={9}>
                      Henüz senkronizasyon
                      çalışması bulunmuyor.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </>
      ) : null}

      {canWrite &&
      query.data &&
      dialog?.kind === 'create' ? (
        <CreateConnectionDialog
          locations={unusedLocations}
          onClose={() =>
            setDialog(null)
          }
        />
      ) : null}

      {canWrite &&
      dialog?.kind === 'edit' ? (
        <EditConnectionDialog
          connection={dialog.connection}
          onClose={() =>
            setDialog(null)
          }
        />
      ) : null}
    </section>
  )
}
