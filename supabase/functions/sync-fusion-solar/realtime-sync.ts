import { FusionSolarClient } from './fusion-solar-api.ts'

export async function syncRealTimeData(
  userId: string,
  stationCode: string,
  token: string,
  fusionSolarAPI: FusionSolarClient,
  supabaseClient: any
): Promise<void> {
  // Get devices for the station
  const devicesResponse = await fusionSolarAPI.apiCall(
    '/thirdData/getDevList',
    token,
    { stationCodes: stationCode }
  )

  if (!devicesResponse?.success || !devicesResponse.data) {
    console.warn(`No devices found for station ${stationCode}`)
    return
  }

  // Find inverter (type 38) and meter (type 47)
  const inverter = devicesResponse.data.find((d: any) => d.devTypeId === 38)
  const meter = devicesResponse.data.find((d: any) => d.devTypeId === 47)

  let realTimeData: any = {
    user_id: userId,
    station_code: stationCode,
    active_power: 0,
    temperature: 0,
    efficiency: 0,
    grid_power: 0,
    fetched_at: new Date().toISOString()
  }

  // Get real-time data from inverter
  if (inverter?.devDn) {
    const inverterDataResponse = await fusionSolarAPI.apiCall(
      '/thirdData/getDevRealKpi',
      token,
      { devTypeId: 38, devIds: inverter.devDn }
    )

    if (inverterDataResponse?.success && inverterDataResponse.data?.[0]) {
      const invData = inverterDataResponse.data[0].dataItemMap || {}
      
      realTimeData = {
        ...realTimeData,
        dev_dn: inverter.devDn,
        active_power: parseFloat(invData.active_power || '0'),
        temperature: parseFloat(invData.temperature || '0'),
        efficiency: parseFloat(invData.efficiency || '0')
      }
    }
  }

  // Get real-time data from meter
  if (meter?.devDn) {
    const meterDataResponse = await fusionSolarAPI.apiCall(
      '/thirdData/getDevRealKpi',
      token,
      { devTypeId: 47, devIds: meter.devDn }
    )

    if (meterDataResponse?.success && meterDataResponse.data?.[0]) {
      const meterData = meterDataResponse.data[0].dataItemMap || {}
      realTimeData.grid_power = parseFloat(meterData.active_power || '0') / 1000 // W to kW
    }
  }

  // Save real-time data to database
  await supabaseClient
    .from('real_time_data')
    .upsert(realTimeData, { onConflict: 'user_id,station_code' })
}