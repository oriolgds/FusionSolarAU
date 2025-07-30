import { FusionSolarAPI } from './fusion-solar-api.ts'

export async function syncDevices(
  userId: string,
  stationCode: string,
  token: string,
  fusionSolarAPI: FusionSolarAPI,
  supabaseClient: any
): Promise<any[]> {
  try {
    // Get devices from API
    const devicesResponse = await fusionSolarAPI.apiCall(
      '/thirdData/getDevList',
      token,
      { stationCodes: stationCode }
    )

    if (!devicesResponse?.success || !devicesResponse.data) {
      console.warn(`No devices found for station ${stationCode}, checking cache`)
      
      // Fallback to cached data
      const { data: cachedDevices } = await supabaseClient
        .from('devices')
        .select('*')
        .eq('user_id', userId)
        .eq('station_code', stationCode)
      
      return cachedDevices || []
    }

    // Process and save devices
    const devices = devicesResponse.data.map((device: any) => ({
      user_id: userId,
      station_code: stationCode,
      dev_dn: device.devDn,
      device_type: device.devTypeId === 38 ? 'inverter' : 'meter',
      updated_at: new Date().toISOString()
    }))

    // Delete existing devices for this station
    await supabaseClient
      .from('devices')
      .delete()
      .eq('user_id', userId)
      .eq('station_code', stationCode)

    // Insert new devices
    if (devices.length > 0) {
      const { error } = await supabaseClient
        .from('devices')
        .insert(devices)

      if (error) {
        console.error('Error saving devices:', error)
        throw error
      }
    }

    return devices
  } catch (error) {
    console.error(`Error syncing devices for station ${stationCode}:`, error)
    
    // Fallback to cached data
    const { data: cachedDevices } = await supabaseClient
      .from('devices')
      .select('*')
      .eq('user_id', userId)
      .eq('station_code', stationCode)
    
    return cachedDevices || []
  }
}