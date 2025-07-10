# Sistema de Datos en Tiempo Real del Inversor - FusionSolarAU

## Descripción General

Este sistema implementa la obtención y visualización de datos en tiempo real del inversor solar usando las APIs de FusionSolar con un sistema de cacheo optimizado en Supabase para respetar los límites de llamadas de la API.

## APIs Implementadas

### 1. Device List API (`/thirdData/getDevList`)
- **Endpoint**: `https://eu5.fusionsolar.huawei.com/thirdData/getDevList`
- **Límite**: 24 llamadas por día
- **Propósito**: Obtener la lista de dispositivos de una planta solar
- **Datos de entrada**:
  ```json
  {
    "stationCodes": "NE=181814243"
  }
  ```
- **Datos de salida relevantes**:
  - `devDn`: Identificador único del dispositivo (ej: "NE=181814245")
  - `devTypeId`: Tipo de dispositivo (38 = inversor residencial)
  - `devName`: Nombre del dispositivo

### 2. Device Real KPI API (`/thirdData/getDevRealKpi`)
- **Endpoint**: `https://eu5.fusionsolar.huawei.com/thirdData/getDevRealKpi`
- **Límite**: 1 llamada cada 5 minutos por dispositivo
- **Propósito**: Obtener datos en tiempo real del inversor
- **Datos de entrada**:
  ```json
  {
    "devTypeId": 38,
    "devIds": "NE=181814245"
  }
  ```
- **Datos de salida relevantes**:
  - `active_power`: Potencia activa en kW
  - `temperature`: Temperatura del inversor en °C
  - `efficiency`: Eficiencia del inversor en %

## Estructura de Base de Datos

### Tabla: `device_cache`
Cachea información de dispositivos por planta para minimizar llamadas a la Device List API.

```sql
CREATE TABLE device_cache (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    station_code TEXT NOT NULL,
    dev_dn TEXT NOT NULL, -- Device DN del inversor residencial
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, station_code)
);
```

### Tabla: `real_time_data`
Almacena datos en tiempo real del inversor con timestamps para control de rate limiting.

```sql
CREATE TABLE real_time_data (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    station_code TEXT NOT NULL,
    dev_dn TEXT NOT NULL,
    active_power DECIMAL(10,3), -- kW
    temperature DECIMAL(5,1),   -- °C
    efficiency DECIMAL(5,2),    -- %
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## Arquitectura del Sistema

### Servicios

#### `InverterRealTimeService`
- **Responsabilidad**: Gestionar la obtención de datos en tiempo real del inversor
- **Funcionalidades**:
  - Cacheo inteligente con respeto a rate limits
  - Obtención automática del device DN
  - Fallback a datos cached en caso de error
  - Rate limiting automático

#### `InverterRealTimeProvider`
- **Responsabilidad**: Provider de estado para la UI
- **Funcionalidades**:
  - Actualización automática cada 5 minutos
  - Gestión de estados de carga y error
  - Notificación a widgets suscritos

### Flujo de Datos

1. **Inicialización**:
   - Usuario selecciona una planta
   - Provider establece el código de estación
   - Se inicia el timer de actualización (5 minutos)

2. **Obtención de Device DN**:
   - Buscar en caché `device_cache`
   - Si no existe o es antiguo (>7 días), hacer fetch de Device List API
   - Filtrar por `devTypeId: 38` (inversor residencial)
   - Cachear el primer `devDn` encontrado

3. **Obtención de Datos en Tiempo Real**:
   - Verificar rate limit (1 llamada cada 5 minutos)
   - Si no se puede hacer fetch, devolver datos cached
   - Hacer llamada a Device Real KPI API
   - Guardar datos en `real_time_data`
   - Notificar a la UI

### Rate Limiting

#### Device List API (24 llamadas/día)
- Se cuenta el número de registros en `device_cache` creados hoy
- Solo se permite fetch si `count < 24`
- El caché es válido por 7 días

#### Device Real KPI API (1 cada 5 minutos)
- Se verifica si existe un registro en `real_time_data` en los últimos 5 minutos
- Solo se permite fetch si no hay registros recientes
- El caché se considera fresco por 5 minutos

## Interfaz de Usuario

### Tarjeta de Datos en Tiempo Real
- **Ubicación**: Dashboard principal, después del selector de plantas
- **Elementos visuales**:
  - Indicador de estado (conectado/desconectado)
  - Progreso de carga
  - Tres métricas principales:
    - Potencia Activa (kW) con icono de rayo
    - Temperatura (°C) con icono de termómetro  
    - Eficiencia (%) con icono de velocímetro
  - Timestamp de última actualización

### Estados de la UI
- **Cargando**: Spinner y texto "Obteniendo datos..."
- **Con datos**: Métricas actualizadas con timestamp
- **Sin datos**: Placeholders "--" 
- **Error**: Mensaje de error en container rojo

## Manejo de Errores

### Estrategias de Fallback
1. **Sin configuración OAuth**: Mostrar "--" en todas las métricas
2. **Rate limit alcanzado**: Usar datos cached aunque sean antiguos
3. **Error de red**: Usar datos cached y mostrar error si persiste
4. **No hay device DN**: Mostrar mensaje de error específico

### Logging
- Se usa `Logger` para registrar:
  - Inicialización de servicios
  - Rate limiting decisions
  - Errores de API
  - Cache hits/misses
  - Actualizaciones exitosas

## Beneficios del Sistema

### Para el Usuario
- **Información en tiempo real**: Datos actualizados del estado del inversor
- **Interfaz clara**: Visualización simple de métricas clave
- **Confiabilidad**: Sistema resiliente con fallbacks

### Para el Sistema
- **Eficiencia**: Respeta límites de API con cacheo inteligente
- **Escalabilidad**: Arquitectura modular y extensible
- **Mantenibilidad**: Separación clara de responsabilidades

## Uso del Sistema

### Integración en el Dashboard
```dart
// El provider se registra en main.dart
ChangeNotifierProvider(create: (_) => InverterRealTimeProvider())

// Se configura automáticamente cuando se selecciona una planta
inverterProvider.setStationCode(stationCode);

// Se consume en la UI
Consumer<InverterRealTimeProvider>(
  builder: (context, provider, _) {
    return Text('${provider.activePower.toStringAsFixed(3)} kW');
  },
)
```

### Actualización Manual
```dart
// Forzar actualización ignorando rate limits y caché
await inverterProvider.forceRefresh();
```

## Consideraciones de Rendimiento

- **Cacheo agresivo**: Minimiza llamadas a API
- **Rate limiting preventivo**: Evita errores por exceso de llamadas
- **Actualizaciones eficientes**: Solo notifica cambios reales
- **Limpieza automática**: Datos antiguos se pueden limpiar automáticamente

## Configuración y Mantenimiento

### Variables de Entorno
- Las URLs de API están hardcoded en el servicio
- Los tokens se manejan a través de `FusionSolarOAuthService`

### Monitoreo
- Logs detallados permiten debugging
- Métricas de rate limiting visibles en logs
- Estados de error claramente identificados

### Limpieza de Datos
- Función SQL opcional para limpiar datos antiguos (>30 días)
- Se puede ejecutar como tarea programada en Supabase
