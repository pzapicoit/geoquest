# player-alias-uniqueness Specification

## Purpose
TBD - created by syncing change int-111-panel-jugadores-delta-1. Update Purpose after archive.

## Requirements

### Requirement: Alias único entre jugadores
El sistema SHALL impedir que dos perfiles con `role = 'jugador'` compartan el mismo `nombre`.

#### Scenario: Alta anónima con alias por defecto colisionado
- **WHEN** el generador de alias por defecto del alta anónima produce un candidato que ya usa otro jugador
- **THEN** el alta reintenta con otro candidato hasta encontrar uno libre, sin que el registro falle

#### Scenario: Cambio de apodo a uno ya usado
- **WHEN** un jugador intenta guardar un apodo que ya usa otro jugador
- **THEN** la actualización falla por la restricción de unicidad y la app muestra un mensaje específico de "alias ya en uso", distinto del genérico de conexión

#### Scenario: Migración de datos existentes duplicados
- **WHEN** se aplica la migración sobre perfiles con alias duplicados
- **THEN** se conserva el alias del perfil más antiguo de cada grupo (por fecha de alta) y a los demás se les añade un sufijo numerado (" (2)", " (3)"...), truncando la parte base si hace falta para no superar los 16 caracteres permitidos
