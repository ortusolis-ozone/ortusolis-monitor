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
          status: string
          status_date: string
          updated_at: string
        }
        Insert: {
          client_id: string
          cold_room_id: string
          generator_id: string
          location_id: string
          status: string
          status_date: string
          updated_at?: string
        }
        Update: {
          client_id?: string
          cold_room_id?: string
          generator_id?: string
          location_id?: string
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
          created_at: string
          deactivated_at: string | null
          generator_id: string
          id: string
          identifier: string
          is_active: boolean
          updated_at: string
        }
        Insert: {
          activated_at: string
          client_id: string
          created_at?: string
          deactivated_at?: string | null
          generator_id: string
          id?: string
          identifier: string
          is_active?: boolean
          updated_at?: string
        }
        Update: {
          activated_at?: string
          client_id?: string
          created_at?: string
          deactivated_at?: string | null
          generator_id?: string
          id?: string
          identifier?: string
          is_active?: boolean
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
          updated_at: string
        }
        Insert: {
          client_id: string
          created_at?: string
          id?: string
          identifier: string
          is_active?: boolean
          updated_at?: string
        }
        Update: {
          client_id?: string
          created_at?: string
          id?: string
          identifier?: string
          is_active?: boolean
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
          created_at: string
          event_id: number
          generator_id: string
          id: number
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
          created_at?: string
          event_id: number
          generator_id: string
          id?: never
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
          created_at?: string
          event_id?: number
          generator_id?: string
          id?: never
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
      [_ in never]: never
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
