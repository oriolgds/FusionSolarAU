import { FusionSolarAPI } from './fusion-solar-api.ts'

export async function syncRealTimeData(
  userId: string,
  stationCode: string,
  token: string,
  fusionSolarAPI: FusionSolarAPI,
  supabaseClient: any
): Promise<void> {
  try {
    // Get devices from cache (devices should be synced separately)
    const { data: devices } = await supabaseClient
      .from('devices')
      .select('*')
      .eq('user_id', userId)
      .eq('station_code', stationCode)

    if (!devices || devices.length === 0) {
      console.warn(`No cached devices found for station ${stationCode}`)
      return
    }

    // Find inverter (type 38) and meter (type 47)
    const inverter = devices.find((d: any) => d.dev_type_id === 38)
    const meter = devices.find((d: any) => d.dev_type_id === 47)

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
    if (inverter?.dev_dn) {
      const inverterDataResponse = await fusionSolarAPI.apiCall(
        '/thirdData/getDevRealKpi',
        token,
        { devTypeId: 38, devIds: inverter.dev_dn }
      )

      if (inverterDataResponse?.success && inverterDataResponse.data?.[0]) {
        const invData = inverterDataResponse.data[0].dataItemMap || {}
        
        realTimeData = {
          ...realTimeData,
          dev_dn: inverter.dev_dn,
          active_power: parseFloat(invData.active_power || '0'),
          temperature: parseFloat(invData.temperature || '0'),
          efficiency: parseFloat(invData.efficiency || '0')
        }
      }
    }

    // Get real-time data from meter
    if (meter?.dev_dn) {
      const meterDataResponse = await fusionSolarAPI.apiCall(
        '/thirdData/getDevRealKpi',
        token,
        { devTypeId: 47, devIds: meter.dev_dn }
      )

      if (meterDataResponse?.success && meterDataResponse.data?.[0]) {
        const meterData = meterDataResponse.data[0].dataItemMap || {}
        realTimeData.grid_power = parseFloat(meterData.active_power || '0') / 1000 // W to kW
      }
    }

    // Save real-time data to database
    const { error } = await supabaseClient
      .from('real_time_data')
      .upsert(realTimeData, { onConflict: 'user_id,station_code' })

    if (error) {
      console.error('Error saving real-time data:', error)
      throw error
    }

    console.log(`Real-time data synced for station ${stationCode}`)
  } catch (error) {
    console.error(`Error syncing real-time data for station ${stationCode}:`, error)
    throw error
  }
}