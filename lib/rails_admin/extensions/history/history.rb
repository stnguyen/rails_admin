class RailsAdmin::History
  include Mongoid::Document
  include Mongoid::Timestamps

  store_in :collection => "rails_admin_histories"

  field :message, type: String
  field :item, type: String
  field :table, type: String
  field :username, type: String

  def self.latest
    limit(100)
  end

  def self.create_history_item(message, object, abstract_model, user)
    create(
       message: [message].flatten.join(', '),
       item: object.id,
       table: abstract_model.to_s,
       username: user.try(:email)
     )
  end

  def self.history_for_model(abstract_model, query, sort, sort_reverse, all, page, per_page = (RailsAdmin::Config.default_items_per_page || 20))
    history = where(table: abstract_model.to_s)
    history_for_model_or_object(history, abstract_model, query, sort, sort_reverse, all, page, per_page)
  end

  def self.history_for_object(abstract_model, object, query, sort, sort_reverse, all, page, per_page = (RailsAdmin::Config.default_items_per_page || 20))
    history = where(table: abstract_model.to_s, item: object.id)
    history_for_model_or_object(history, abstract_model, query, sort, sort_reverse, all, page, per_page)
  end

protected

  def self.history_for_model_or_object(history, abstract_model, query, sort, sort_reverse, all, page, per_page)
    history = history.where('message LIKE ? OR username LIKE ?', "%#{query}%", "%#{query}%") if query
    history = history.order(sort_reverse == 'true' ? "#{sort} DESC" : sort) if sort
    all ? history : history.send(Kaminari.config.page_method_name, page.presence || '1').per(per_page)
  end
end
