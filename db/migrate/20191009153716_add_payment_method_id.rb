class AddPaymentMethodId < SolidusSupport::Migration[4.2]
  def change
    add_column :affirm_checkouts, :payment_method_id, :integer
  end
end
