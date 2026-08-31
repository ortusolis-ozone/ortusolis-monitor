export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      application_power_verifications: {
        Row: {
          application_id: number
          controller_id: string | null
          created_at: string
          generator_id: string
          power_off_reading_id: number | null
          power_on_reading_id: number | null
          source_updated_at: string
          status: string
          technical_reason: string
          updated_at: string
        }
        Insert: {
          application_id: number
          controller_id?: string | null
          created_at?: string
          generator_id: string
          power_off_reading_id?: number | null
          power_on_reading_id?: number | null
          source_updated_at: string
          status: string
          technical_reason: string
          updated_at?: string
        }
        Update: {
          application_id?: number
          controller_id?: string | null
          created_at?: string
          generator_id?: string
          power_off_reading_id?: number | null
          power_on_reading_id?: number | null
          source_updated_at?: string
          status?: string
          technical_reason?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "application_power_verifications_application_id_fkey"
            columns: ["application_id"]
            isOneToOne: true
            referencedRelation: "applications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "application_power_verifications_controller_id_fkey"
            columns: ["controller_id"]
            isOneToOne: false
            referencedRelation: "controllers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "application_power_verifications_generator_id_fkey"
            columns: ["generator_id"]
            isOneToOne: false
            referencedRelation: "generators"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "application_power_verifications_off_context_fkey"
            columns: ["power_off_reading_id", "generator_id", "controller_id"]
            isOneToOne: false
            referencedRelation: "power_readings"
            referencedColumns: ["id", "generator_id", "controller_id"]
          },
          {
            foreignKeyName: "application_power_verifications_on_context_fkey"
            columns: ["power_on_reading_id", "generator_id", "controller_id"]
            isOneToOne: false
            referencedRelation: "power_readings"
            referencedColumns: ["id", "generator_id", "controller_id"]
          },
        ]
      }
      applications: {
        Row: {
          controller_id: string
          created_at: string
          end_event_id: number
          generator_id: string
          id: number
          public_date: string
          start_event_id: number
        }
        Insert: {
          controller_id: string
          created_at?: string
          end_event_id: number
          generator_id: string
          id?: never
          public_date: string
          start_event_id: number
        }
        Update: {
          controller_id?: string
          created_at?: string
          end_event_id?: number
          generator_id?: string
          id?: never
          public_date?: string
          start_event_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "applications_controller_id_fkey"
            columns: ["controller_id"]
            isOneToOne: false
            referencedRelation: "controllers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "applications_end_event_context_fkey"
            columns: ["end_event_id", "generator_id", "controller_id"]
            isOneToOne: false
            referencedRelation: "raw_events"
            referencedColumns: ["id", "generator_id", "controller_id"]
          },
          {
            foreignKeyName: "applications_generator_id_fkey"
            columns: ["generator_id"]
            isOneToOne: false
            referencedRelation: "generators"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "applications_start_event_context_fkey"
            columns: ["start_event_id", "generator_id", "controller_id"]
            isOneToOne: false
            referencedRelation: "raw_events"
            referencedColumns: ["id", "generator_id", "controller_id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          entity_id: string
          entity_type: string
          id: number
          occurred_at: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          entity_id: string
          entity_type: string
          id?: never
          occurred_at?: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          entity_id?: string
          entity_type?: string
          id?: never
          occurred_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      client_daily_status: {
        Row: {
          client_id: string
          cold_room_id: string
          generator_id: string
          location_id: string
          power_evidence_status: string
          status: string
          status_date: string
          updated_at: string
        }
        Insert: {
          client_id: string
          cold_room_id: string
          generator_id: string
          location_id: string
          power_evidence_status?: string
          status: string
          status_date: string
          updated_at?: string
        }
        Update: {
          client_id?: string
          cold_room_id?: string
          generator_id?: string
          location_id?: string
          power_evidence_status?: string
          status?: string
          status_date?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "client_daily_status_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "client_daily_status_cold_room_hierarchy_fkey"
            columns: ["cold_room_id", "client_id", "location_id"]
            isOneToOne: false
            referencedRelation: "cold_rooms"
            referencedColumns: ["id", "client_id", "location_id"]
          },
          {
            foreignKeyName: "client_daily_status_generator_client_fkey"
            columns: ["generator_id", "client_id"]
            isOneToOne: false
            referencedRelation: "generators"
            referencedColumns: ["id", "client_id"]
          },
        ]
      }
      clients: {
        Row: {
          cnpj: string
          created_at: string
          id: string
          is_active: boolean
          legal_name: string
          updated_at: string
        }
        Insert: {
          cnpj: string
          created_at?: string
          id?: string
          is_active?: boolean
          legal_name: string
          updated_at?: string
        }
        Update: {
          cnpj?: string
          created_at?: string
          id?: string
          is_active?: boolean
          legal_name?: string
          updated_at?: string
        }
        Relationships: []
      }
      cold_rooms: {
        Row: {
          category: string
          client_id: string
          created_at: string
          id: string
          is_active: boolean
          location_id: string
          name: string
          updated_at: string
        }
        Insert: {
          category: string
          client_id: string
          created_at?: string
          id?: string
          is_active?: boolean
          location_id: string
          name: string
          updated_at?: string
        }
        Update: {
          category?: string
          client_id?: string
          created_at?: string
          id?: string
          is_active?: boolean
          location_id?: string
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "cold_rooms_location_client_fkey"
            columns: ["location_id", "client_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id", "client_id"]
          },
        ]
      }
      controllers: {
        Row: {
          activated_at: string
          client_id: string
          correlation_tolerance_seconds: number | null
          created_at: string
          deactivated_at: string | null
          external_device_id: string | null
          external_device_id_normalized: string | null
          generator_id: string
          id: string
          identifier: string
          is_active: boolean
          power_off_threshold_w: number | null
          power_on_threshold_w: number | null
          role: string
          updated_at: string
        }
        Insert: {
          activated_at: string
          client_id: string
          correlation_tolerance_seconds?: number | null
          created_at?: string
          deactivated_at?: string | null
          external_device_id?: string | null
          external_device_id_normalized?: string | null
          generator_id: string
          id?: string
          identifier: string
          is_active?: boolean
          power_off_threshold_w?: number | null
          power_on_threshold_w?: number | null
          role?: string
          updated_at?: string
        }
        Update: {
          activated_at?: string
          client_id?: string
          correlation_tolerance_seconds?: number | null
          created_at?: string
          deactivated_at?: string | null
          external_device_id?: string | null
          external_device_id_normalized?: string | null
          generator_id?: string
          id?: string
          identifier?: string
          is_active?: boolean
          power_off_threshold_w?: number | null
          power_on_threshold_w?: number | null
          role?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "controllers_generator_client_fkey"
            columns: ["generator_id", "client_id"]
            isOneToOne: false
            referencedRelation: "generators"
            referencedColumns: ["id", "client_id"]
          },
        ]
      }
      generator_assignments: {
        Row: {
          client_id: string
          cold_room_id: string
          created_at: string
          generator_id: string
          id: number
          location_id: string
          valid_from: string
          valid_until: string | null
        }
        Insert: {
          client_id: string
          cold_room_id: string
          created_at?: string
          generator_id: string
          id?: never
          location_id: string
          valid_from: string
          valid_until?: string | null
        }
        Update: {
          client_id?: string
          cold_room_id?: string
          created_at?: string
          generator_id?: string
          id?: never
          location_id?: string
          valid_from?: string
          valid_until?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "generator_assignments_cold_room_hierarchy_fkey"
            columns: ["cold_room_id", "client_id", "location_id"]
            isOneToOne: false
            referencedRelation: "cold_rooms"
            referencedColumns: ["id", "client_id", "location_id"]
          },
          {
            foreignKeyName: "generator_assignments_generator_client_fkey"
            columns: ["generator_id", "client_id"]
            isOneToOne: false
            referencedRelation: "generators"
            referencedColumns: ["id", "client_id"]
          },
        ]
      }
      generators: {
        Row: {
          client_id: string
          created_at: string
          id: string
          identifier: string
          is_active: boolean
          telemetry_status: string
          updated_at: string
        }
        Insert: {
          client_id: string
          created_at?: string
          id?: string
          identifier: string
          is_active?: boolean
          telemetry_status?: string
          updated_at?: string
        }
        Update: {
          client_id?: string
          created_at?: string
          id?: string
          identifier?: string
          is_active?: boolean
          telemetry_status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "generators_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
      import_batches: {
        Row: {
          client_id: string
          cold_room_id: string
          confirmed_at: string | null
          controller_id: string
          created_at: string
          created_by: string
          data_kind: string
          duplicate_rows: number
          error_message: string | null
          file_name: string
          file_sha256: string
          generator_id: string
          id: string
          inserted_rows: number
          location_id: string
          period_end: string | null
          period_start: string | null
          status: string
          total_rows: number
          unknown_source_rows: number
        }
        Insert: {
          client_id: string
          cold_room_id: string
          confirmed_at?: string | null
          controller_id: string
          created_at?: string
          created_by: string
          data_kind?: string
          duplicate_rows?: number
          error_message?: string | null
          file_name: string
          file_sha256: string
          generator_id: string
          id?: string
          inserted_rows?: number
          location_id: string
          period_end?: string | null
          period_start?: string | null
          status?: string
          total_rows?: number
          unknown_source_rows?: number
        }
        Update: {
          client_id?: string
          cold_room_id?: string
          confirmed_at?: string | null
          controller_id?: string
          created_at?: string
          created_by?: string
          data_kind?: string
          duplicate_rows?: number
          error_message?: string | null
          file_name?: string
          file_sha256?: string
          generator_id?: string
          id?: string
          inserted_rows?: number
          location_id?: string
          period_end?: string | null
          period_start?: string | null
          status?: string
          total_rows?: number
          unknown_source_rows?: number
        }
        Relationships: [
          {
            foreignKeyName: "import_batches_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "import_batches_cold_room_hierarchy_fkey"
            columns: ["cold_room_id", "client_id", "location_id"]
            isOneToOne: false
            referencedRelation: "cold_rooms"
            referencedColumns: ["id", "client_id", "location_id"]
          },
          {
            foreignKeyName: "import_batches_controller_hierarchy_fkey"
            columns: ["controller_id", "client_id", "generator_id"]
            isOneToOne: false
            referencedRelation: "controllers"
            referencedColumns: ["id", "client_id", "generator_id"]
          },
          {
            foreignKeyName: "import_batches_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "import_batches_generator_client_fkey"
            columns: ["generator_id", "client_id"]
            isOneToOne: false
            referencedRelation: "generators"
            referencedColumns: ["id", "client_id"]
          },
        ]
      }
      inconsistencies: {
        Row: {
          application_id: number | null
          created_at: string
          event_id: number | null
          generator_id: string
          id: number
          power_reading_id: number | null
          public_date: string
          related_event_id: number | null
          resolved_at: string | null
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          type: string
        }
        Insert: {
          application_id?: number | null
          created_at?: string
          event_id?: number | null
          generator_id: string
          id?: never
          power_reading_id?: number | null
          public_date: string
          related_event_id?: number | null
          resolved_at?: string | null
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          type: string
        }
        Update: {
          application_id?: number | null
          created_at?: string
          event_id?: number | null
          generator_id?: string
          id?: never
          power_reading_id?: number | null
          public_date?: string
          related_event_id?: number | null
          resolved_at?: string | null
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "inconsistencies_application_id_fkey"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "applications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inconsistencies_event_generator_fkey"
            columns: ["event_id", "generator_id"]
            isOneToOne: false
            referencedRelation: "raw_events"
            referencedColumns: ["id", "generator_id"]
          },
          {
            foreignKeyName: "inconsistencies_generator_id_fkey"
            columns: ["generator_id"]
            isOneToOne: false
            referencedRelation: "generators"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inconsistencies_power_reading_generator_fkey"
            columns: ["power_reading_id", "generator_id"]
            isOneToOne: false
            referencedRelation: "power_readings"
            referencedColumns: ["id", "generator_id"]
          },
          {
            foreignKeyName: "inconsistencies_related_event_generator_fkey"
            columns: ["related_event_id", "generator_id"]
            isOneToOne: false
            referencedRelation: "raw_events"
            referencedColumns: ["id", "generator_id"]
          },
          {
            foreignKeyName: "inconsistencies_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      locations: {
        Row: {
          client_id: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          time_zone: string
          updated_at: string
        }
        Insert: {
          client_id: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          time_zone?: string
          updated_at?: string
        }
        Update: {
          client_id?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          time_zone?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "locations_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
      power_readings: {
        Row: {
          client_id: string
          cold_room_id: string
          controller_id: string
          created_at: string
          device_id: string
          device_id_normalized: string
          device_name: string
          event_detail: string
          event_name: string
          event_type: string
          fingerprint: string
          generator_id: string
          id: number
          import_batch_id: string
          location_id: string
          occurred_at: string
          occurred_at_raw: string
          power_raw: string
          power_w: number
          request_from: string
          source_detail: string
        }
        Insert: {
          client_id: string
          cold_room_id: string
          controller_id: string
          created_at?: string
          device_id: string
          device_id_normalized: string
          device_name: string
          event_detail: string
          event_name: string
          event_type: string
          fingerprint: string
          generator_id: string
          id?: never
          import_batch_id: string
          location_id: string
          occurred_at: string
          occurred_at_raw: string
          power_raw: string
          power_w: number
          request_from?: string
          source_detail?: string
        }
        Update: {
          client_id?: string
          cold_room_id?: string
          controller_id?: string
          created_at?: string
          device_id?: string
          device_id_normalized?: string
          device_name?: string
          event_detail?: string
          event_name?: string
          event_type?: string
          fingerprint?: string
          generator_id?: string
          id?: never
          import_batch_id?: string
          location_id?: string
          occurred_at?: string
          occurred_at_raw?: string
          power_raw?: string
          power_w?: number
          request_from?: string
          source_detail?: string
        }
        Relationships: [
          {
            foreignKeyName: "power_readings_batch_context_fkey"
            columns: ["import_batch_id", "generator_id", "controller_id"]
            isOneToOne: false
            referencedRelation: "import_batches"
            referencedColumns: ["id", "generator_id", "controller_id"]
          },
          {
            foreignKeyName: "power_readings_cold_room_context_fkey"
            columns: ["cold_room_id", "client_id", "location_id"]
            isOneToOne: false
            referencedRelation: "cold_rooms"
            referencedColumns: ["id", "client_id", "location_id"]
          },
          {
            foreignKeyName: "power_readings_controller_context_fkey"
            columns: ["controller_id", "client_id", "generator_id"]
            isOneToOne: false
            referencedRelation: "controllers"
            referencedColumns: ["id", "client_id", "generator_id"]
          },
          {
            foreignKeyName: "power_readings_generator_context_fkey"
            columns: ["generator_id", "client_id"]
            isOneToOne: false
            referencedRelation: "generators"
            referencedColumns: ["id", "client_id"]
          },
        ]
      }
      profiles: {
        Row: {
          client_id: string | null
          created_at: string
          full_name: string
          id: string
          is_active: boolean
          role: string
          updated_at: string
        }
        Insert: {
          client_id?: string | null
          created_at?: string
          full_name: string
          id: string
          is_active?: boolean
          role: string
          updated_at?: string
        }
        Update: {
          client_id?: string | null
          created_at?: string
          full_name?: string
          id?: string
          is_active?: boolean
          role?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
      raw_events: {
        Row: {
          controller_id: string
          created_at: string
          fingerprint: string
          generator_id: string
          id: number
          import_batch_id: string
          occurred_at: string
          occurred_at_raw: string
          operation: string
          operation_raw: string
          source_classification: string
          source_normalized: string
          source_original: string
        }
        Insert: {
          controller_id: string
          created_at?: string
          fingerprint: string
          generator_id: string
          id?: never
          import_batch_id: string
          occurred_at: string
          occurred_at_raw: string
          operation: string
          operation_raw: string
          source_classification: string
          source_normalized: string
          source_original: string
        }
        Update: {
          controller_id?: string
          created_at?: string
          fingerprint?: string
          generator_id?: string
          id?: never
          import_batch_id?: string
          occurred_at?: string
          occurred_at_raw?: string
          operation?: string
          operation_raw?: string
          source_classification?: string
          source_normalized?: string
          source_original?: string
        }
        Relationships: [
          {
            foreignKeyName: "raw_events_batch_context_fkey"
            columns: ["import_batch_id", "generator_id", "controller_id"]
            isOneToOne: false
            referencedRelation: "import_batches"
            referencedColumns: ["id", "generator_id", "controller_id"]
          },
        ]
      }
      source_mappings: {
        Row: {
          classification: string
          created_at: string
          created_by: string
          id: number
          is_active: boolean
          normalized_source: string
          updated_at: string
        }
        Insert: {
          classification: string
          created_at?: string
          created_by: string
          id?: never
          is_active?: boolean
          normalized_source: string
          updated_at?: string
        }
        Update: {
          classification?: string
          created_at?: string
          created_by?: string
          id?: never
          is_active?: boolean
          normalized_source?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_mappings_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      confirm_power_xlsx_import: {
        Args: {
          p_client_id: string
          p_cold_room_id: string
          p_controller_id: string
          p_file_name: string
          p_file_sha256: string
          p_generator_id: string
          p_location_id: string
          p_readings: Json
        }
        Returns: Json
      }
      confirm_xlsx_import: {
        Args: {
          p_client_id: string
          p_cold_room_id: string
          p_controller_id: string
          p_events: Json
          p_file_name: string
          p_file_sha256: string
          p_generator_id: string
          p_location_id: string
        }
        Returns: Json
      }
      deactivate_controller: {
        Args: { p_controller_id: string; p_deactivated_on: string }
        Returns: undefined
      }
      existing_event_fingerprints: {
        Args: { p_fingerprints: string[] }
        Returns: {
          fingerprint: string
        }[]
      }
      existing_power_fingerprints: {
        Args: { p_fingerprints: string[] }
        Returns: {
          fingerprint: string
        }[]
      }
      list_admin_inconsistencies: {
        Args: {
          p_client_id?: string
          p_end_date?: string
          p_generator_id?: string
          p_location_id?: string
          p_start_date?: string
          p_status?: string
          p_type?: string
        }
        Returns: {
          client_id: string
          client_name: string
          created_at: string
          event_controller_identifier: string
          event_id: number
          event_occurred_at: string
          event_operation: string
          event_source_classification: string
          event_source_normalized: string
          event_source_original: string
          generator_id: string
          generator_identifier: string
          id: number
          location_id: string
          location_name: string
          public_date: string
          related_event_controller_identifier: string
          related_event_id: number
          related_event_occurred_at: string
          related_event_operation: string
          related_event_source_classification: string
          related_event_source_original: string
          review_note: string
          reviewed_at: string
          reviewed_by: string
          reviewed_by_name: string
          status: string
          type: string
        }[]
      }
      list_admin_inconsistencies_v2: {
        Args: {
          p_client_id?: string
          p_end_date?: string
          p_generator_id?: string
          p_location_id?: string
          p_start_date?: string
          p_status?: string
          p_type?: string
        }
        Returns: {
          client_id: string
          client_name: string
          correlated_power_off_at: string
          correlated_power_off_w: number
          correlated_power_on_at: string
          correlated_power_on_w: number
          created_at: string
          event_controller_identifier: string
          event_id: number
          event_occurred_at: string
          event_operation: string
          event_source_classification: string
          event_source_normalized: string
          event_source_original: string
          generator_id: string
          generator_identifier: string
          id: number
          location_id: string
          location_name: string
          power_controller_identifier: string
          power_device_id: string
          power_device_name: string
          power_occurred_at: string
          power_reading_id: number
          power_w: number
          public_date: string
          related_event_controller_identifier: string
          related_event_id: number
          related_event_occurred_at: string
          related_event_operation: string
          related_event_source_classification: string
          related_event_source_original: string
          review_note: string
          reviewed_at: string
          reviewed_by: string
          reviewed_by_name: string
          status: string
          type: string
          verification_reason: string
          verification_status: string
        }[]
      }
      list_source_values: {
        Args: never
        Returns: {
          classification: string
          event_count: number
          example_source: string
          is_active: boolean
          last_seen_at: string
          normalized_source: string
        }[]
      }
      reactivate_controller: {
        Args: { p_controller_id: string }
        Returns: undefined
      }
      reassign_generator: {
        Args: {
          p_cold_room_id: string
          p_effective_on: string
          p_generator_id: string
          p_location_id: string
        }
        Returns: number
      }
      record_failed_power_xlsx_import: {
        Args: {
          p_client_id: string
          p_cold_room_id: string
          p_controller_id: string
          p_error_message: string
          p_file_name: string
          p_file_sha256: string
          p_generator_id: string
          p_location_id: string
        }
        Returns: string
      }
      record_failed_xlsx_import: {
        Args: {
          p_client_id: string
          p_cold_room_id: string
          p_controller_id: string
          p_error_message: string
          p_file_name: string
          p_file_sha256: string
          p_generator_id: string
          p_location_id: string
        }
        Returns: string
      }
      register_complete_client_structure: {
        Args: {
          p_client_cnpj: string
          p_client_legal_name: string
          p_cold_room_category: string
          p_cold_room_name: string
          p_controller_activated_on: string
          p_controller_identifier: string
          p_generator_identifier: string
          p_generator_valid_from: string
          p_location_description: string
          p_location_name: string
          p_location_time_zone: string
        }
        Returns: Json
      }
      register_complete_client_structure_v2: {
        Args: {
          p_client_cnpj: string
          p_client_legal_name: string
          p_cold_room_category: string
          p_cold_room_name: string
          p_correlation_tolerance_seconds?: number
          p_generator_identifier: string
          p_generator_valid_from: string
          p_location_description: string
          p_location_name: string
          p_location_time_zone: string
          p_power_controller_activated_on: string
          p_power_controller_device_id: string
          p_power_controller_identifier: string
          p_power_off_threshold_w?: number
          p_power_on_threshold_w?: number
          p_state_controller_activated_on: string
          p_state_controller_identifier: string
        }
        Returns: Json
      }
      register_controller: {
        Args: {
          p_activated_on: string
          p_generator_id: string
          p_identifier: string
        }
        Returns: string
      }
      register_controller_v2: {
        Args: {
          p_activated_on: string
          p_correlation_tolerance_seconds?: number
          p_external_device_id?: string
          p_generator_id: string
          p_identifier: string
          p_power_off_threshold_w?: number
          p_power_on_threshold_w?: number
          p_role: string
        }
        Returns: string
      }
      register_generator: {
        Args: {
          p_client_id: string
          p_cold_room_id: string
          p_identifier: string
          p_location_id: string
          p_valid_from: string
        }
        Returns: string
      }
      register_generator_v2: {
        Args: {
          p_client_id: string
          p_cold_room_id: string
          p_correlation_tolerance_seconds?: number
          p_identifier: string
          p_location_id: string
          p_power_controller_activated_on: string
          p_power_controller_device_id: string
          p_power_controller_identifier: string
          p_power_off_threshold_w?: number
          p_power_on_threshold_w?: number
          p_state_controller_activated_on: string
          p_state_controller_identifier: string
          p_valid_from: string
        }
        Returns: string
      }
      reopen_inconsistency: {
        Args: { p_inconsistency_id: number }
        Returns: boolean
      }
      replace_controller: {
        Args: {
          p_activated_on: string
          p_generator_id: string
          p_identifier: string
        }
        Returns: string
      }
      replace_controller_v2: {
        Args: {
          p_activated_on: string
          p_correlation_tolerance_seconds?: number
          p_external_device_id?: string
          p_generator_id: string
          p_identifier: string
          p_power_off_threshold_w?: number
          p_power_on_threshold_w?: number
          p_role: string
        }
        Returns: string
      }
      reprocess_generator_telemetry: {
        Args: { p_generator_id: string }
        Returns: undefined
      }
      review_inconsistency: {
        Args: { p_inconsistency_id: number; p_review_note?: string }
        Returns: boolean
      }
      set_source_mapping: {
        Args: { p_classification: string; p_normalized_source: string }
        Returns: number
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
