require 'active_model_serializers'

module SolidusAffirm
  class CheckoutPayloadSerializer < ActiveModel::Serializer
    attributes :merchant, :shipping, :billing, :items, :discounts, :metadata,
    :order_id, :shipping_amount, :tax_amount, :total

    def merchant
      hsh = {
        user_confirmation_url: object.config[:confirmation_url],
        user_cancel_url: object.config[:cancel_url]
      }
      hsh[:name] = object.config[:name] if object.config[:name].present?
      hsh
    end

    def shipping
      AddressSerializer.new(object.ship_address)
    end

    def billing
      AddressSerializer.new(object.bill_address)
    end

    def items
      ActiveModel::Serializer::CollectionSerializer.new(
        object.items,
        serializer: LineItemSerializer,
        root: false
      )
    end

    def discounts
      discounts = order_promotions.merge(line_item_promotions, &promo_merge)

      discounts.empty? ? nil : discounts
    end

    def order_promotions
      object.order.adjustments
        .select(&promo_filter)
        .to_h do |adjustment|
          [
            promo_name(adjustment),
            {
              discount_amount: promo_amount(adjustment),
              discount_display_name: promo_name(adjustment),
            }
          ]
        end
    end

    def line_item_promotions
      line_item_promotions = []

      object.order.line_items.each do |item|
        item.adjustments
          .select(&promo_filter)
          .each do |adjustment|
          line_item_promotions.push(
            {
              promo_name(adjustment) => {
                discount_amount: promo_amount(adjustment),
                discount_display_name: promo_name(adjustment),
              }
            }
          )
        end
      end

      line_item_promotions.reduce({}) do |promo_hash, promo|
        promo_hash.merge(promo, &promo_merge)
      end
    end

    def promo_filter
      ->(adjustment) {adjustment.source_type == "Spree::PromotionAction" && adjustment.amount != 0}
    end

    def promo_merge
      ->(key, p1, p2) do
        {
          discount_amount: p1[:discount_amount] + p2[:discount_amount],
          discount_display_name: p1[:discount_display_name],
        }
      end
    end

    def promo_name(adjustment)
      adjustment.promotion_code.promotion.name
    end

    def promo_amount(adjustment)
      (adjustment.amount.to_money.cents) * -1
    end

    def order_id
      object.order.number
    end

    def shipping_amount
      object.order.shipment_total.to_money.cents
    end

    def tax_amount
      object.order.tax_total.to_money.cents
    end

    def total
      object.order.order_total_after_store_credit.to_money.cents
    end

    def metadata
      return nil if object.metadata.empty?

      object.metadata
    end
  end
end
