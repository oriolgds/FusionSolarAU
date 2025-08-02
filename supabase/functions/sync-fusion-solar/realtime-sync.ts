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

    // Get last sync preference to alternate between devices
    const { data: lastSync } = await supabaseClient
      .from('sync_preferences')
      .select('last_device_sync')
      .eq('user_id', userId)
      .single()
    
    const lastDevice = lastSync?.last_device_sync || 'meter'
    const priorityDevice = lastDevice === 'inverter' ? 'meter' : 'inverter'
    
    // Sync priority device first
    if (priorityDevice === 'inverter' && inverter?.dev_dn) {
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
      
      // Try to sync meter as well
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
    } else if (priorityDevice === 'meter' && meter?.dev_dn) {
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
      
      // Try to sync inverter as well
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
    }
    
    // Update last sync preference
    await supabaseClient
      .from('sync_preferences')
      .upsert({ user_id: userId, last_device_sync: priorityDevice })
  } catch (error) {
    console.error(`Error syncing real-time data:`, error)
  }
}
