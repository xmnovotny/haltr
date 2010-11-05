class PeopleController < ApplicationController

  unloadable
  menu_item :haltr

  helper :sort
  include SortHelper

  before_filter :find_client, :except => [:edit,:destroy,:update]
  before_filter :authorize

  def index
    sort_init 'last_name', 'asc'
    sort_update %w(first_name last_name email)

    c = ARCondition.new(["client_id = ?", @client])

    unless params[:name].blank?
      name = "%#{params[:name].strip.downcase}%"
      c << ["LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ? OR LOWER(email) LIKE ?", name, name, name]
    end

    @person_count = Person.count(:conditions => c.conditions)
    @person_pages = Paginator.new self, @person_count,
		per_page_option,
		params['page']
    @people = Person.find :all, :order => sort_clause,
       :conditions => c.conditions,
       :limit  => @person_pages.items_per_page,
       :offset => @person_pages.current.offset

    render :action => "index", :layout => false if request.xhr?
  end

  def new
    @person = Person.new
  end

  def edit
    @person = Person.find(params[:id])
  end

  def create
    @person = Person.new(params[:person].merge({:client=>@client}))
    if @person.save
      flash[:notice] = 'Person was successfully created.'
      redirect_to :action => 'index', :id => @client
    else
      render :action => "new"
    end
  end

  def update
    @person = Person.find(params[:id])
    if @person.update_attributes(params[:person])
      flash[:notice] = 'Person was successfully updated.'
      redirect_to :action => 'index', :id => @person.client
    else
      render :action => "edit"
    end
  end

  def destroy
    @person = Person.find(params[:id])
    @person.destroy
    redirect_to :action => 'index', :id => @person.client
  end

  private

  def find_client
    @client = Client.find params[:id]
    @project = @client.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end
