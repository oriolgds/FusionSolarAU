export interface FusionSolarClient {
  login(username: string, password: string): Promise<string | null>
  apiCall(endpoint: string, token: string, body: any): Promise<any>
}

export class FusionSolarAPI implements FusionSolarClient {
  private baseUrl = 'https://eu5.fusionsolar.huawei.com'

  async login(username: string, password: string): Promise<string | null> {
    try {
      const response = await fetch(`${this.baseUrl}/thirdData/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userName: username, systemCode: password })
      })
      
      if (response.ok) {
        const data = await response.json()
        if (data.success) {
          const cookies = response.headers.get('set-cookie') || ''
          const tokenMatch = cookies.match(/XSRF-TOKEN=([^;]+)/)
          return tokenMatch ? tokenMatch[1] : null
        }
      }
      return null
    } catch (error) {
      console.error('Login error:', error)
      return null
    }
  }

  async apiCall(endpoint: string, token: string, body: any): Promise<any> {
    try {
      const response = await fetch(`${this.baseUrl}${endpoint}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Cookie': `XSRF-TOKEN=${token}`,
          'XSRF-TOKEN': token
        },
        body: JSON.stringify(body)
      })
      
      if (response.ok) {
        return await response.json()
      }
      return null
    } catch (error) {
      console.error('API call error:', error)
      return null
    }
  }
}