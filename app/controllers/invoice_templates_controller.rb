class InvoiceTemplatesController < ApplicationController 

  unloadable
  menu_item :haltr_invoices

  helper :invoices
  layout 'haltr'
  helper :haltr
  helper :sort
  include SortHelper

  before_filter :find_invoice_template, :except => [:index,:new,:create,:new_from_invoice,:invoices,:create_invoices,:update_taxes]
  before_filter :find_project, :only => [:index,:new,:create,:invoices,:create_invoices,:update_taxes]
  before_filter :find_invoice, :only => [:new_from_invoice]
  before_filter :authorize

  verify :method => [:post,:put], :only => [:create,:update], :redirect_to => :root_path

  include CompanyFilter
  before_filter :check_for_company

  def index
    sort_init 'date', 'asc'
    sort_update %w(date number clients.name)

    templates = @project.invoice_templates.scoped(nil)

    unless params[:name].blank?
      name = "%#{params[:name].strip.downcase}%"
      templates = templates.scoped :conditions => ["LOWER(name) LIKE ? OR LOWER(address) LIKE ? OR LOWER(address2) LIKE ?", name, name, name]
    end

    @invoice_count = templates.count
    @invoice_pages = Paginator.new self, @invoice_count,
		per_page_option,
		params['page']
    @invoices =  templates.find :all,
       :order => sort_clause,
       :include => [:client],
       :limit  =>  @invoice_pages.items_per_page,
       :offset =>  @invoice_pages.current.offset
  end

  def new
    @invoice = InvoiceTemplate.new(:client_id=>params[:client],:project=>@project,:date=>Date.today)
    @client = Client.find(params[:client]) if params[:client]
    @client ||= Client.find(:all, :order => 'name', :conditions => ["project_id = ?", @project]).first
    @client ||= Client.new
    render :template => "invoices/new"
  end

  def edit
    @invoice = InvoiceTemplate.find(params[:id])
    render :template => "invoices/edit"
  end

  def create
    @invoice = InvoiceTemplate.new(params[:invoice])
    @client = @invoice.client
    @invoice.project=@project
    if @invoice.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index', :id => @project
    else
      render :template => "invoices/new"
    end
  end

  def update
    if @invoice.update_attributes(params[:invoice])
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'index', :id => @project
    else
      render :template => "invoices/edit"
    end
  end

  def destroy
    @invoice.destroy
    redirect_to :action => 'index', :id => @project
  end

  def show
    @invoices_generated = @invoice.issued_invoices.sort
    render :template => "invoices/show"
  end

  def new_from_invoice
    @invoice = InvoiceTemplate.new(@issued_invoice.attributes)
    @invoice.number=nil
    @issued_invoice.invoice_lines.each do |line|
      tl = InvoiceLine.new(line.attributes)
      line.taxes.each do |tax|
        tl.taxes << Tax.new(tax.attributes)
      end
      @invoice.invoice_lines << tl
    end
    render :template => "invoices/new"
  end

  def invoices
    @number = IssuedInvoice.next_number(@project)
    days = params[:date] || 10
    @date = Date.today + days.to_i.day
    templates = InvoiceTemplate.find :all, :include => [:client], :conditions => ["clients.project_id = ? and date <= ?", @project.id, @date], :order => "date ASC"
    @drafts = DraftInvoice.find :all, :include => [:client], :conditions => ["clients.project_id = ?", @project.id], :order => "date ASC"
    templates.each do |t|
      begin
        @drafts << t.invoices_until(@date)
      rescue ActiveRecord::RecordInvalid => e
        flash.now[:warning] = l(:warning_can_not_generate_invoice,t.to_s)
        flash.now[:error] = e.message
      end
    end
    @drafts.flatten!

  end

  def create_invoices
    @number = IssuedInvoice.next_number(@project)
    drafts_to_process=[]
    @invoices = []
    if params[:draft_ids]
      params[:draft_ids].each do |draft_id|
        drafts_to_process << DraftInvoice.find(draft_id)
      end
    end
    drafts_to_process.each do |draft|
      issued = IssuedInvoice.new(draft.attributes)
      issued.number = params["draft_#{draft.id}"]
      draft.invoice_lines.each do |draft_line|
        l = InvoiceLine.new draft_line.attributes
        draft_line.taxes.each do |tax|
          l.taxes << Tax.new(:name=>tax.name,:percent=>tax.percent)
        end
        issued.invoice_lines << l
      end
      if issued.valid?
        draft.destroy
        issued.id=draft.id
        issued.save
        @invoices << issued
      else
        flash.now[:error] = issued.errors.full_messages.join ","
      end
    end
    @drafts = DraftInvoice.find :all, :include => [:client], :conditions => ["clients.project_id = ?", @project.id], :order => "date ASC"
    render :action => 'invoices'
  end

  def update_taxes
    num_changed = 0
    from_name = params[:from_name]
    from_percent = params[:from_percent].to_i
    @used_taxes = []
    @project.invoice_templates.each do |template|
      template_changed = false
      template.invoice_lines.each do |line|
        line.taxes.each do |tax|
          if tax.name == from_name and tax.percent == from_percent
            tax.name = params[:to_name]
            tax.percent = params[:to_percent].to_i
            if tax.save
              num_changed = num_changed + 1
              template_changed = true
            end
          end
          @used_taxes << tax unless @used_taxes.include? tax
        end
      end
      template.save if template_changed
    end
    flash.now[:notice] = "Updated #{num_changed} template lines" if from_name and from_percent
  end

  private

  def find_invoice_template
    @invoice = InvoiceTemplate.find params[:id]
    @lines = @invoice.invoice_lines
    @client = @invoice.client
    @project = @invoice.project
    @company = @invoice.company
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_invoice
    @issued_invoice = IssuedInvoice.find params[:id]
    @client = @issued_invoice.client
    @project = @issued_invoice.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end
