import { FusionSolarAPI } from './fusion-solar-api.ts'

export async function syncRealTimeData(
  userId: string,
  stationCode: string,
  token: string,
  fusionSolarAPI: FusionSolarAPI,
  supabaseClient: any
): Promise<void> {
  try {
    const { data: devices } = await supabaseClient
      .from('devices')
      .select('*')
      .eq('user_id', userId)
      .eq('station_code', stationCode)

    if (!devices || devices.length === 0) {
      console.warn(`No devices found for station ${stationCode}`)
      return
    }

    const inverter = devices.find((d: any) => d.device_type === 'inverter')
    const meter = devices.find((d: any) => d.device_type === 'meter')

    // Sync inverter data
    if (inverter?.dev_dn) {
      const inverterResponse = await fusionSolarAPI.apiCall(
        '/thirdData/getDevRealKpi',
        token,
        { devTypeId: 38, devIds: inverter.dev_dn }
      )

      if (inverterResponse?.success && inverterResponse.data?.[0]) {
        const invData = inverterResponse.data[0].dataItemMap || {}
        
        await supabaseClient
          .from('inverter_data')
          .upsert({
            user_id: userId,
            station_code: stationCode,
            dev_dn: inverter.dev_dn,
            active_power: parseFloat(invData.active_power || '0'),
            temperature: parseFloat(invData.temperature || '0'),
            efficiency: parseFloat(invData.efficiency || '0')
          }, { onConflict: 'user_id' })
      }
    }

    // Sync meter data
    if (meter?.dev_dn) {
      const meterResponse = await fusionSolarAPI.apiCall(
        '/thirdData/getDevRealKpi',
        token,
        { devTypeId: 47, devIds: meter.dev_dn }
      )

      if (meterResponse?.success && meterResponse.data?.[0]) {
        const meterData = meterResponse.data[0].dataItemMap || {}
        
        await supabaseClient
          .from('meter_data')
          .upsert({
            user_id: userId,
            station_code: stationCode,
            dev_dn: meter.dev_dn,
            active_power: parseFloat(meterData.active_power || '0') / 1000,
            voltage: parseFloat(meterData.voltage || '0'),
            current: parseFloat(meterData.current || '0'),
            frequency: parseFloat(meterData.frequency || '0'),
            status: parseInt(meterData.status || '1')
          }, { onConflict: 'user_id' })
      }
    }

    console.log(`Real-time data synced for user ${userId}`)
  } catch (error) {
    console.error(`Error syncing real-time data:`, error)
    throw error
  }
}