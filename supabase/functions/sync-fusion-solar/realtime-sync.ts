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
      .select('dev_dn, device_type')
      .eq('user_id', userId)
      .eq('station_code', stationCode)

    if (!devices || devices.length === 0) {
      return
    }

    const inverter = devices.find((d: any) => d.device_type === 'inverter')
    const meter = devices.find((d: any) => d.device_type === 'meter')

    // Try to get both devices in one call if both exist
    if (inverter?.dev_dn && meter?.dev_dn) {
      const combinedResponse = await fusionSolarAPI.apiCall(
        '/thirdData/getDevRealKpi',
        token,
        { devIds: `${inverter.dev_dn},${meter.dev_dn}` }
      )

      if (combinedResponse?.success && combinedResponse.data) {
        for (const deviceData of combinedResponse.data) {
          const dataMap = deviceData.dataItemMap || {}
          
          if (deviceData.devDn === inverter.dev_dn) {
            await supabaseClient
              .from('inverter_data')
              .upsert({
                user_id: userId,
                station_code: stationCode,
                dev_dn: inverter.dev_dn,
                active_power: parseFloat(dataMap.active_power || '0'),
                temperature: parseFloat(dataMap.temperature || '0'),
                efficiency: parseFloat(dataMap.efficiency || '0')
              }, { onConflict: 'user_id' })
          } else if (deviceData.devDn === meter.dev_dn) {
            await supabaseClient
              .from('meter_data')
              .upsert({
                user_id: userId,
                station_code: stationCode,
                dev_dn: meter.dev_dn,
                active_power: parseFloat(dataMap.active_power || '0') / 1000,
                voltage: parseFloat(dataMap.voltage || '0'),
                current: parseFloat(dataMap.current || '0'),
                frequency: parseFloat(dataMap.frequency || '0'),
                status: parseInt(dataMap.status || '1')
              }, { onConflict: 'user_id' })
          }
        }
        return
      }
    }

    // Fallback: sync inverter only if combined call fails
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
  } catch (error) {
    console.error(`Error syncing real-time data:`, error)
    throw error
  }
}