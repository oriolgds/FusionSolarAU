import { FusionSolarAPI } from './fusion-solar-api.ts'
import { syncPlants } from './plant-sync.ts'
import { syncDevices } from './device-sync.ts'
import { syncDailyData } from './daily-data-sync.ts'
import { syncRealTimeData } from './realtime-sync.ts'

async function loginAndCacheToken(
  user: any,
  fusionSolarAPI: FusionSolarAPI,
  supabaseClient: any
): Promise<string | null> {
  const token = await fusionSolarAPI.login(
    user.fusion_solar_api_username,
    user.fusion_solar_api_password
  )
  
  if (token) {
    await supabaseClient
      .from('users')
      .update({ fusion_solar_xsrf_token: token })
      .eq('id', user.id)
  }
  
  return token
}

async function handleTokenExpired(
  user: any,
  fusionSolarAPI: FusionSolarAPI,
  supabaseClient: any
): Promise<string | null> {
  console.log(`Token expired for user ${user.id}, re-logging in`)
  return await loginAndCacheToken(user, fusionSolarAPI, supabaseClient)
}

export async function syncUserData(
  user: any, 
  fusionSolarAPI: FusionSolarAPI, 
  supabaseClient: any
) {
  const result = {
    userId: user.id,
    status: 'success' as 'success' | 'error',
    plantsProcessed: 0,
    plantsFromCache: false,
    devicesFromCache: false,
    dailyDataLimited: false,
    error: null as string | null
  }

  try {
    // Try to use cached token first
    let token = user.fusion_solar_xsrf_token
    
    // If no cached token or token is invalid, login
    if (!token) {
      token = await loginAndCacheToken(user, fusionSolarAPI, supabaseClient)
    }
    
    if (!token) {
      throw new Error(`Failed to login for user ${user.id}`)
    }

    // Get and sync plants with token retry logic
    let plantsResult
    try {
      plantsResult = await syncPlants(user.id, token, fusionSolarAPI, supabaseClient)
    } catch (error: any) {
      // Check if token expired
      if (error.message.includes('USER_MUST_RELOGIN') || error.message.includes('Failed to get plants')) {
        token = await handleTokenExpired(user, fusionSolarAPI, supabaseClient)
        if (!token) {
          throw new Error(`Failed to re-login for user ${user.id}`)
        }
        plantsResult = await syncPlants(user.id, token, fusionSolarAPI, supabaseClient)
      } else {
        throw error
      }
    }
    
    if (!plantsResult.plants || plantsResult.plants.length === 0) {
      throw new Error(`No plants found for user ${user.id}`)
    }

    result.plantsProcessed = plantsResult.plants.length
    result.plantsFromCache = plantsResult.fromCache

    // Sync data for each plant
    let anyDevicesFromCache = false
    let anyDailyDataLimited = false
    for (const plant of plantsResult.plants) {
      // Sync devices first (needed for real-time data)
      const devicesResult = await syncDevices(user.id, plant.station_code, token, fusionSolarAPI, supabaseClient)
      if (devicesResult.fromCache) anyDevicesFromCache = true
      
      // Sync daily and real-time data
      const dailyDataSynced = await syncDailyData(user.id, plant.station_code, token, fusionSolarAPI, supabaseClient)
      if (!dailyDataSynced) anyDailyDataLimited = true
      
      await syncRealTimeData(user.id, plant.station_code, token, fusionSolarAPI, supabaseClient)
    }

    result.devicesFromCache = anyDevicesFromCache
    result.dailyDataLimited = anyDailyDataLimited
    return result
  } catch (error: any) {
    result.status = 'error'
    result.error = error.message
    return result
  }
}