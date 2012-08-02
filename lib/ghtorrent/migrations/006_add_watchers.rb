require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do
  up do

    puts("Adding table watchers")

    create_table :watchers do
      foreign_key :repo_id, :projects, :null => false
      foreign_key :user_id, :users, :null => false
      DateTime :created_at, :null => false,
               :default => Sequel::CURRENT_TIMESTAMP
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
      primary_key [:repo_id, :user_id]
    end
  end

  down do

    drop_table :watchers

  end
end