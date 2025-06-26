import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_provider.dart';
import '../../models/smart_device.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  String _selectedRoom = 'Todos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos'),
        actions: [
          Consumer<DeviceProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: provider.isLoading ? null : provider.refreshDevices,
              );
            },
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.devices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar dispositivos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: provider.refreshDevices,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (provider.devices.isEmpty) {
            return const Center(
              child: Text('No hay dispositivos configurados'),
            );
          }

          final rooms = ['Todos', ...provider.uniqueRooms];
          final filteredDevices = _selectedRoom == 'Todos'
              ? provider.devices
              : provider.getDevicesByRoom(_selectedRoom);

          return Column(
            children: [
              // Filtro por habitación
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final isSelected = room == _selectedRoom;
                    
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: FilterChip(
                        label: Text(room),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedRoom = room;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              
              // Lista de dispositivos
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.refreshDevices,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDevices.length,
                    itemBuilder: (context, index) {
                      final device = filteredDevices[index];
                      return _buildDeviceCard(context, device, provider);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, SmartDevice device, DeviceProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Ícono del dispositivo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getDeviceColor(device).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getDeviceIcon(device.type),
                    color: _getDeviceColor(device),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Información del dispositivo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${device.roomName} • ${device.typeDisplayName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Estado y control
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Switch(
                      value: device.isOn,
                      onChanged: device.status == DeviceStatus.online
                          ? (value) => provider.toggleDevice(device.id)
                          : null,
                    ),
                    Text(
                      _getStatusText(device.status),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(device.status),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            if (device.isOn && device.powerConsumption > 0) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.flash_on,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Consumo: ${device.powerConsumption.toStringAsFixed(0)} W',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (device.canBeAutomated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Automatizable',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return Icons.lightbulb;
      case DeviceType.switch_:
        return Icons.toggle_on;
      case DeviceType.thermostat:
        return Icons.thermostat;
      case DeviceType.outlet:
        return Icons.power;
      case DeviceType.fan:
        return Icons.air;
      case DeviceType.speaker:
        return Icons.speaker;
      case DeviceType.display:
        return Icons.tv;
      case DeviceType.camera:
        return Icons.camera_alt;
      case DeviceType.lock:
        return Icons.lock;
      case DeviceType.vacuum:
        return Icons.cleaning_services;
      case DeviceType.washer:
        return Icons.local_laundry_service;
      case DeviceType.dryer:
        return Icons.dry_cleaning;
      case DeviceType.dishwasher:
        return Icons.kitchen;
      case DeviceType.oven:
        return Icons.microwave;
      case DeviceType.airConditioner:
        return Icons.ac_unit;
      case DeviceType.heater:
        return Icons.fireplace;
      case DeviceType.charger:
        return Icons.ev_station;
      case DeviceType.other:
        return Icons.device_unknown;
    }
  }

  Color _getDeviceColor(SmartDevice device) {
    if (device.status != DeviceStatus.online) {
      return Colors.grey;
    }
    
    switch (device.type) {
      case DeviceType.light:
        return Colors.yellow;
      case DeviceType.thermostat:
      case DeviceType.airConditioner:
      case DeviceType.heater:
        return Colors.blue;
      case DeviceType.charger:
        return Colors.green;
      case DeviceType.washer:
      case DeviceType.dryer:
      case DeviceType.dishwasher:
        return Colors.purple;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getStatusText(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return 'En línea';
      case DeviceStatus.offline:
        return 'Fuera de línea';
      case DeviceStatus.error:
        return 'Error';
      case DeviceStatus.updating:
        return 'Actualizando';
    }
  }

  Color _getStatusColor(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return Colors.green;
      case DeviceStatus.offline:
        return Colors.grey;
      case DeviceStatus.error:
        return Colors.red;
      case DeviceStatus.updating:
        return Colors.orange;
    }
  }
}
