import { FusionSolarAPI } from './fusion-solar-api.ts'
import { syncPlants } from './plant-sync.ts'
import { syncDevices } from './device-sync.ts'
import { syncDailyData } from './daily-data-sync.ts'
import { syncRealTimeData } from './realtime-sync.ts'

export async function syncUserData(
  user: any, 
  fusionSolarAPI: FusionSolarAPI, 
  supabaseClient: any
) {
  // Login to FusionSolar
  const token = await fusionSolarAPI.login(
    user.fusion_solar_api_username,
    user.fusion_solar_api_password
  )

  if (!token) {
    throw new Error(`Failed to login for user ${user.id}`)
  }

  // Get and sync plants
  const plants = await syncPlants(user.id, token, fusionSolarAPI, supabaseClient)
  
  if (!plants || plants.length === 0) {
    throw new Error(`No plants found for user ${user.id}`)
  }

  // Sync data for each plant
  for (const plant of plants) {
    // Sync devices first (needed for real-time data)
    await syncDevices(user.id, plant.stationCode, token, fusionSolarAPI, supabaseClient)
    
    // Sync daily and real-time data
    await syncDailyData(user.id, plant.stationCode, token, fusionSolarAPI, supabaseClient)
    await syncRealTimeData(user.id, plant.stationCode, token, fusionSolarAPI, supabaseClient)
  }

  return { 
    userId: user.id, 
    status: 'success', 
    plantsProcessed: plants.length 
  }
}