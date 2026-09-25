export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      audit_logs: {
        Row: {
          action: string
          actor_user_id: string | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: string
          location_id: string | null
          metadata: Json
          tenant_id: string
        }
        Insert: {
          action: string
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: string
          location_id?: string | null
          metadata?: Json
          tenant_id: string
        }
        Update: {
          action?: string
          actor_user_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: string
          location_id?: string | null
          metadata?: Json
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_location_fk"
            columns: ["location_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "audit_logs_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_accounts: {
        Row: {
          account_type: string
          created_at: string
          currency_code: string
          id: string
          location_id: string | null
          name: string
          status: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          account_type: string
          created_at?: string
          currency_code?: string
          id?: string
          location_id?: string | null
          name: string
          status?: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          account_type?: string
          created_at?: string
          currency_code?: string
          id?: string
          location_id?: string | null
          name?: string
          status?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_accounts_location_fk"
            columns: ["location_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "finance_accounts_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_entries: {
        Row: {
          account_id: string
          amount: number
          created_at: string
          id: string
          tenant_id: string
          transaction_id: string
        }
        Insert: {
          account_id: string
          amount: number
          created_at?: string
          id?: string
          tenant_id: string
          transaction_id: string
        }
        Update: {
          account_id?: string
          amount?: number
          created_at?: string
          id?: string
          tenant_id?: string
          transaction_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_entries_account_fk"
            columns: ["account_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "finance_entries_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_entries_transaction_fk"
            columns: ["transaction_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "finance_transactions"
            referencedColumns: ["id", "tenant_id"]
          },
        ]
      }
      finance_transactions: {
        Row: {
          created_at: string
          created_by_user_id: string
          description: string | null
          id: string
          location_id: string | null
          occurred_at: string
          source_id: string | null
          source_type: string | null
          tenant_id: string
          transaction_type: string
        }
        Insert: {
          created_at?: string
          created_by_user_id: string
          description?: string | null
          id?: string
          location_id?: string | null
          occurred_at: string
          source_id?: string | null
          source_type?: string | null
          tenant_id: string
          transaction_type: string
        }
        Update: {
          created_at?: string
          created_by_user_id?: string
          description?: string | null
          id?: string
          location_id?: string | null
          occurred_at?: string
          source_id?: string | null
          source_type?: string | null
          tenant_id?: string
          transaction_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_transactions_location_fk"
            columns: ["location_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "finance_transactions_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_count_lines: {
        Row: {
          count_id: string
          counted_quantity: number | null
          difference: number | null
          id: string
          inventory_item_id: string
          system_quantity: number
          tenant_id: string
        }
        Insert: {
          count_id: string
          counted_quantity?: number | null
          difference?: number | null
          id?: string
          inventory_item_id: string
          system_quantity: number
          tenant_id: string
        }
        Update: {
          count_id?: string
          counted_quantity?: number | null
          difference?: number | null
          id?: string
          inventory_item_id?: string
          system_quantity?: number
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_count_lines_count_id_tenant_id_fkey"
            columns: ["count_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "inventory_counts"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "inventory_count_lines_inventory_item_id_tenant_id_fkey"
            columns: ["inventory_item_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "inventory_count_lines_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_counts: {
        Row: {
          cancelled_at: string | null
          cancelled_by: string | null
          counted_at: string
          created_at: string
          created_by: string
          id: string
          location_id: string
          notes: string | null
          posted_at: string | null
          posted_by: string | null
          status: string
          tenant_id: string
        }
        Insert: {
          cancelled_at?: string | null
          cancelled_by?: string | null
          counted_at?: string
          created_at?: string
          created_by: string
          id?: string
          location_id: string
          notes?: string | null
          posted_at?: string | null
          posted_by?: string | null
          status?: string
          tenant_id: string
        }
        Update: {
          cancelled_at?: string | null
          cancelled_by?: string | null
          counted_at?: string
          created_at?: string
          created_by?: string
          id?: string
          location_id?: string
          notes?: string | null
          posted_at?: string | null
          posted_by?: string | null
          status?: string
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_counts_location_id_tenant_id_fkey"
            columns: ["location_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "inventory_counts_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_items: {
        Row: {
          base_unit: string
          category: string | null
          created_at: string
          critical_stock: number | null
          id: string
          name: string
          sku: string | null
          status: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          base_unit: string
          category?: string | null
          created_at?: string
          critical_stock?: number | null
          id?: string
          name: string
          sku?: string | null
          status?: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          base_unit?: string
          category?: string | null
          created_at?: string
          critical_stock?: number | null
          id?: string
          name?: string
          sku?: string | null
          status?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_items_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_movements: {
        Row: {
          created_at: string
          created_by_user_id: string
          description: string
          id: string
          inventory_item_id: string
          location_id: string
          movement_type: string
          occurred_at: string
          quantity: number
          source_id: string | null
          source_type: string | null
          tenant_id: string
        }
        Insert: {
          created_at?: string
          created_by_user_id: string
          description: string
          id?: string
          inventory_item_id: string
          location_id: string
          movement_type: string
          occurred_at?: string
          quantity: number
          source_id?: string | null
          source_type?: string | null
          tenant_id: string
        }
        Update: {
          created_at?: string
          created_by_user_id?: string
          description?: string
          id?: string
          inventory_item_id?: string
          location_id?: string
          movement_type?: string
          occurred_at?: string
          quantity?: number
          source_id?: string | null
          source_type?: string | null
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_movements_inventory_item_id_tenant_id_fkey"
            columns: ["inventory_item_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "inventory_movements_location_id_tenant_id_fkey"
            columns: ["location_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "inventory_movements_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      locations: {
        Row: {
          created_at: string
          id: string
          name: string
          status: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          status?: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          status?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "locations_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      membership_invitation_roles: {
        Row: {
          created_at: string
          invitation_id: string
          role_id: string
          tenant_id: string
        }
        Insert: {
          created_at?: string
          invitation_id: string
          role_id: string
          tenant_id: string
        }
        Update: {
          created_at?: string
          invitation_id?: string
          role_id?: string
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "membership_invitation_roles_invitation_fk"
            columns: ["invitation_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "membership_invitations"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "membership_invitation_roles_role_fk"
            columns: ["role_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "membership_invitation_roles_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      membership_invitations: {
        Row: {
          accepted_at: string | null
          created_at: string
          email: string
          expires_at: string
          id: string
          invited_by_user_id: string
          status: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          accepted_at?: string | null
          created_at?: string
          email: string
          expires_at: string
          id?: string
          invited_by_user_id: string
          status?: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          accepted_at?: string | null
          created_at?: string
          email?: string
          expires_at?: string
          id?: string
          invited_by_user_id?: string
          status?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "membership_invitations_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      membership_roles: {
        Row: {
          created_at: string
          membership_id: string
          role_id: string
          tenant_id: string
        }
        Insert: {
          created_at?: string
          membership_id: string
          role_id: string
          tenant_id: string
        }
        Update: {
          created_at?: string
          membership_id?: string
          role_id?: string
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "membership_roles_membership_fk"
            columns: ["membership_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "memberships"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "membership_roles_role_fk"
            columns: ["role_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "membership_roles_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      memberships: {
        Row: {
          created_at: string
          id: string
          status: string
          tenant_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          status?: string
          tenant_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          status?: string
          tenant_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "memberships_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      outbox_events: {
        Row: {
          aggregate_id: string | null
          aggregate_type: string
          attempts: number
          event_type: string
          id: string
          occurred_at: string
          payload: Json
          processed_at: string | null
          tenant_id: string
        }
        Insert: {
          aggregate_id?: string | null
          aggregate_type: string
          attempts?: number
          event_type: string
          id?: string
          occurred_at?: string
          payload?: Json
          processed_at?: string | null
          tenant_id: string
        }
        Update: {
          aggregate_id?: string | null
          aggregate_type?: string
          attempts?: number
          event_type?: string
          id?: string
          occurred_at?: string
          payload?: Json
          processed_at?: string | null
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "outbox_events_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          display_name: string | null
          id: string
          locale: string
          timezone: string
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          id: string
          locale?: string
          timezone?: string
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          id?: string
          locale?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      purchase_invoice_lines: {
        Row: {
          created_at: string
          description: string
          gross_amount: number
          id: string
          inventory_item_id: string | null
          line_no: number
          net_amount: number
          price_includes_tax: boolean
          purchase_invoice_id: string
          quantity: number
          supplier_product_code: string | null
          tax_amount: number
          tax_rate: number
          tenant_id: string
          unit: string
          unit_price: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          description: string
          gross_amount: number
          id?: string
          inventory_item_id?: string | null
          line_no: number
          net_amount: number
          price_includes_tax: boolean
          purchase_invoice_id: string
          quantity: number
          supplier_product_code?: string | null
          tax_amount: number
          tax_rate: number
          tenant_id: string
          unit: string
          unit_price: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string
          gross_amount?: number
          id?: string
          inventory_item_id?: string | null
          line_no?: number
          net_amount?: number
          price_includes_tax?: boolean
          purchase_invoice_id?: string
          quantity?: number
          supplier_product_code?: string | null
          tax_amount?: number
          tax_rate?: number
          tenant_id?: string
          unit?: string
          unit_price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_invoice_inventory_item_tenant_fk"
            columns: ["inventory_item_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "purchase_invoice_lines_purchase_invoice_id_tenant_id_fkey"
            columns: ["purchase_invoice_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "purchase_invoices"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "purchase_invoice_lines_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      purchase_invoices: {
        Row: {
          created_at: string
          created_by_user_id: string
          currency_code: string
          description: string | null
          due_date: string | null
          grand_total: number
          id: string
          invoice_date: string
          invoice_number: string
          location_id: string | null
          posted_at: string | null
          posted_by_user_id: string | null
          status: string
          subtotal: number
          supplier_id: string
          tax_total: number
          tenant_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by_user_id: string
          currency_code: string
          description?: string | null
          due_date?: string | null
          grand_total: number
          id?: string
          invoice_date: string
          invoice_number: string
          location_id?: string | null
          posted_at?: string | null
          posted_by_user_id?: string | null
          status?: string
          subtotal: number
          supplier_id: string
          tax_total: number
          tenant_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by_user_id?: string
          currency_code?: string
          description?: string | null
          due_date?: string | null
          grand_total?: number
          id?: string
          invoice_date?: string
          invoice_number?: string
          location_id?: string | null
          posted_at?: string | null
          posted_by_user_id?: string | null
          status?: string
          subtotal?: number
          supplier_id?: string
          tax_total?: number
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_invoices_location_id_tenant_id_fkey"
            columns: ["location_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "purchase_invoices_supplier_id_tenant_id_fkey"
            columns: ["supplier_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "purchase_invoices_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          created_at: string
          permission_key: string
          role_id: string
          tenant_id: string
        }
        Insert: {
          created_at?: string
          permission_key: string
          role_id: string
          tenant_id: string
        }
        Update: {
          created_at?: string
          permission_key?: string
          role_id?: string
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_role_fk"
            columns: ["role_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "role_permissions_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          created_at: string
          id: string
          is_system: boolean
          key: string
          name: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_system?: boolean
          key: string
          name: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          is_system?: boolean
          key?: string
          name?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "roles_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_ledger_entries: {
        Row: {
          amount: number
          created_at: string
          created_by_user_id: string
          currency_code: string
          description: string
          entry_type: string
          id: string
          occurred_at: string
          source_id: string | null
          source_type: string
          supplier_id: string
          tenant_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          created_by_user_id: string
          currency_code: string
          description: string
          entry_type: string
          id?: string
          occurred_at: string
          source_id?: string | null
          source_type: string
          supplier_id: string
          tenant_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          created_by_user_id?: string
          currency_code?: string
          description?: string
          entry_type?: string
          id?: string
          occurred_at?: string
          source_id?: string | null
          source_type?: string
          supplier_id?: string
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_ledger_entries_supplier_id_tenant_id_fkey"
            columns: ["supplier_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "supplier_ledger_entries_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_payments: {
        Row: {
          amount: number
          created_at: string
          created_by_user_id: string
          currency_code: string
          description: string
          finance_account_id: string
          finance_transaction_id: string
          id: string
          occurred_at: string
          supplier_id: string
          tenant_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          created_by_user_id: string
          currency_code: string
          description: string
          finance_account_id: string
          finance_transaction_id: string
          id?: string
          occurred_at: string
          supplier_id: string
          tenant_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          created_by_user_id?: string
          currency_code?: string
          description?: string
          finance_account_id?: string
          finance_transaction_id?: string
          id?: string
          occurred_at?: string
          supplier_id?: string
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_payments_finance_account_id_tenant_id_fkey"
            columns: ["finance_account_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "supplier_payments_finance_transaction_id_tenant_id_fkey"
            columns: ["finance_transaction_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "finance_transactions"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "supplier_payments_supplier_id_tenant_id_fkey"
            columns: ["supplier_id", "tenant_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id", "tenant_id"]
          },
          {
            foreignKeyName: "supplier_payments_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      suppliers: {
        Row: {
          created_at: string
          email: string | null
          id: string
          name: string
          notes: string | null
          phone: string | null
          status: string
          tax_number: string | null
          tenant_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          email?: string | null
          id?: string
          name: string
          notes?: string | null
          phone?: string | null
          status?: string
          tax_number?: string | null
          tenant_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          email?: string | null
          id?: string
          name?: string
          notes?: string | null
          phone?: string | null
          status?: string
          tax_number?: string | null
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "suppliers_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      tenant_modules: {
        Row: {
          created_at: string
          enabled: boolean
          module_key: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          enabled?: boolean
          module_key: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          enabled?: boolean
          module_key?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tenant_modules_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      tenants: {
        Row: {
          created_at: string
          id: string
          name: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      cancel_inventory_count: {
        Args: { p_count_id: string; p_tenant_id: string }
        Returns: string
      }
      create_finance_account: {
        Args: {
          p_account_type: string
          p_currency_code: string
          p_location_id?: string
          p_name: string
          p_tenant_id: string
        }
        Returns: string
      }
      create_finance_adjustment: {
        Args: {
          p_account_id: string
          p_amount: number
          p_description: string
          p_occurred_at?: string
          p_tenant_id: string
        }
        Returns: string
      }
      create_finance_cashflow: {
        Args: {
          p_account_id: string
          p_amount: number
          p_description: string
          p_occurred_at?: string
          p_tenant_id: string
          p_transaction_type: string
        }
        Returns: string
      }
      create_finance_transfer: {
        Args: {
          p_amount: number
          p_description: string
          p_from_account_id: string
          p_occurred_at?: string
          p_tenant_id: string
          p_to_account_id: string
        }
        Returns: string
      }
      create_inventory_count: {
        Args: {
          p_counted_at?: string
          p_location_id: string
          p_notes?: string
          p_tenant_id: string
        }
        Returns: string
      }
      create_inventory_item: {
        Args: {
          p_base_unit: string
          p_category?: string
          p_critical_stock?: number
          p_name: string
          p_sku?: string
          p_tenant_id: string
        }
        Returns: string
      }
      create_inventory_movement: {
        Args: {
          p_description: string
          p_direction?: string
          p_item_id: string
          p_location_id: string
          p_movement_type: string
          p_occurred_at?: string
          p_quantity: number
          p_tenant_id: string
        }
        Returns: string
      }
      create_purchase_invoice_draft: {
        Args: {
          p_currency_code: string
          p_description?: string
          p_due_date?: string
          p_invoice_date: string
          p_invoice_number: string
          p_lines: Json
          p_location_id?: string
          p_supplier_id: string
          p_tenant_id: string
        }
        Returns: string
      }
      create_supplier: {
        Args: {
          p_email?: string
          p_name: string
          p_notes?: string
          p_phone?: string
          p_tax_number?: string
          p_tenant_id: string
        }
        Returns: string
      }
      create_supplier_payment: {
        Args: {
          p_amount: number
          p_description: string
          p_finance_account_id: string
          p_occurred_at?: string
          p_supplier_id: string
          p_tenant_id: string
        }
        Returns: string
      }
      get_finance_account_management: {
        Args: { p_tenant_id: string }
        Returns: Json
      }
      get_finance_overview: {
        Args: { p_recent_limit?: number; p_tenant_id: string }
        Returns: Json
      }
      get_inventory_context: { Args: { p_tenant_id: string }; Returns: Json }
      get_inventory_count_detail: {
        Args: { p_count_id: string; p_tenant_id: string }
        Returns: Json
      }
      get_inventory_counts: { Args: { p_tenant_id: string }; Returns: Json }
      get_inventory_management: { Args: { p_tenant_id: string }; Returns: Json }
      get_inventory_overview: {
        Args: { p_location_id?: string; p_tenant_id: string }
        Returns: Json
      }
      get_my_tenant_context: { Args: { p_tenant_id: string }; Returns: Json }
      get_purchase_invoice_context: {
        Args: { p_tenant_id: string }
        Returns: Json
      }
      get_purchase_invoice_detail: {
        Args: { p_invoice_id: string; p_tenant_id: string }
        Returns: Json
      }
      get_purchase_invoice_overview: {
        Args: { p_recent_limit?: number; p_tenant_id: string }
        Returns: Json
      }
      get_supplier_overview: {
        Args: { p_recent_limit?: number; p_tenant_id: string }
        Returns: Json
      }
      get_supplier_payment_context: {
        Args: { p_tenant_id: string }
        Returns: Json
      }
      post_inventory_count: {
        Args: { p_count_id: string; p_tenant_id: string }
        Returns: string
      }
      post_purchase_invoice: {
        Args: { p_invoice_id: string; p_tenant_id: string }
        Returns: string
      }
      update_finance_account: {
        Args: {
          p_account_id: string
          p_name: string
          p_status: string
          p_tenant_id: string
        }
        Returns: string
      }
      update_inventory_count: {
        Args: { p_count_id: string; p_lines: Json; p_tenant_id: string }
        Returns: string
      }
      update_inventory_item: {
        Args: {
          p_category?: string
          p_critical_stock?: number
          p_item_id: string
          p_name: string
          p_sku?: string
          p_status: string
          p_tenant_id: string
        }
        Returns: string
      }
      update_purchase_invoice_draft: {
        Args: {
          p_currency_code: string
          p_description?: string
          p_due_date?: string
          p_invoice_date: string
          p_invoice_id: string
          p_invoice_number: string
          p_lines: Json
          p_location_id?: string
          p_supplier_id: string
          p_tenant_id: string
        }
        Returns: string
      }
      update_supplier: {
        Args: {
          p_email: string
          p_name: string
          p_notes: string
          p_phone: string
          p_status: string
          p_supplier_id: string
          p_tax_number: string
          p_tenant_id: string
        }
        Returns: string
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
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
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const
