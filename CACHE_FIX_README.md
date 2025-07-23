# Solución para el Caché de Datos del Inversor

Este documento explica cómo solucionar el problema con el caché de datos del inversor en tiempo real.

## Problema

Los datos del inversor en tiempo real se muestran correctamente en la aplicación, pero no se están guardando correctamente en la tabla `real_time_data` de Supabase. Esto provoca que se hagan más llamadas a la API de las necesarias, ya que hay un límite de una llamada cada 5 minutos.

## Solución

### 1. Actualizar la estructura de la base de datos

Ejecuta el siguiente script SQL en tu base de datos Supabase:

```sql
-- Modificaciones para la tabla real_time_data
ALTER TABLE public.real_time_data 
ADD COLUMN IF NOT EXISTS fetched_at timestamp with time zone,
ADD COLUMN IF NOT EXISTS next_fetch_allowed timestamp with time zone;

-- Crear restricción de clave única para evitar duplicados
DO $$
BEGIN
    -- Verificar si la restricción ya existe
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'real_time_data_user_station_unique'
    ) THEN
        -- Crear la restricción si no existe
        ALTER TABLE public.real_time_data 
        ADD CONSTRAINT real_time_data_user_station_unique 
        UNIQUE (user_id, station_code);
    END IF;
END
$$;

-- Crear índice para next_fetch_allowed para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_real_time_data_next_fetch 
ON public.real_time_data (next_fetch_allowed);

-- Verificar si hay datos existentes y actualizarlos
UPDATE public.real_time_data
SET 
    fetched_at = created_at,
    next_fetch_allowed = created_at + interval '5 minutes'
WHERE 
    fetched_at IS NULL;
```

### 2. Actualizar el código

Hay dos opciones:

#### Opción 1: Reemplazar el archivo completo

Reemplaza el archivo `lib/services/inverter_real_time_service.dart` con el archivo `lib/services/inverter_real_time_service_updated.dart`.

#### Opción 2: Actualizar los métodos específicos

Si prefieres hacer cambios más específicos, actualiza los siguientes métodos en `lib/services/inverter_real_time_service.dart`:

1. Actualiza el método `_getCachedRealTimeData` para usar `next_fetch_allowed` en lugar de verificar la edad del registro.
2. Actualiza el método `_saveRealTimeDataToCache` para manejar errores y asegurar que los datos se escriban correctamente.

### 3. Verificar la implementación

1. Ejecuta la aplicación y verifica que los datos del inversor se muestren correctamente.
2. Verifica en la base de datos que los datos se estén guardando correctamente en la tabla `real_time_data`.
3. Verifica que no se estén haciendo más llamadas a la API de las necesarias.

## Explicación técnica

El problema principal era que los datos no se estaban guardando correctamente en la tabla `real_time_data` debido a que:

1. La tabla no tenía las columnas necesarias (`fetched_at` y `next_fetch_allowed`).
2. No había una restricción de clave única para evitar duplicados.
3. El método `_saveRealTimeDataToCache` no manejaba correctamente los errores.
4. El método `_getCachedRealTimeData` no usaba `next_fetch_allowed` para determinar si los datos eran válidos.

Con estos cambios, los datos se guardarán correctamente en la tabla y se respetará el límite de una llamada cada 5 minutos.