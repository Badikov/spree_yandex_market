class Admin::YandexMarketsController < Admin::BaseController  
  before_filter :get_config
  
  def show
    @taxons =  Taxon.roots
  end
  def category
    @taxons =  Taxon.roots
  end
  def currency
  end
  
  def wares 
  end
  
  def export_files
    directory = File.join(RAILS_ROOT,'public', "yandex_market", '**', '*')
    @export_files =  Dir[directory].map {|x| [File.basename(x), File.mtime(x)] }.
      sort{|x,y| y.last <=> x.last }
    e =@export_files.find {|x| x.first == "yandex_market.gz" }
    @export_files.reject! {|x| x.first == "yandex_market.gz" }
    @export_files.unshift(e)


  end
  
  def run_export
    command = %{cd #{ RAILS_ROOT } && RAILS_ENV=#{RAILS_ENV} rake spree:extensions:yandex_market:generate_ym &}
    logger.info "[ yandex market ] Запуск формирование файла экспорта из блока администрирования "
    logger.info "[ yandex market ] команда - #{command} "
    system command
    render :text => "Обновите страницу через несколько минут.", :status => :ok, :layout => false
  end
  
  def update
    @config.attributes = params[:preferences]
    @config.save!
    
    respond_to do |format|
      format.html {
        redirect_to admin_yandex_markets_path
      }
    end
  end
  
  private
  def get_config
    @config = YandexMarket.first
  end
end
