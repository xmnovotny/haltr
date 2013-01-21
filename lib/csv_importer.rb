module CsvImporter

  include CsvMapper

  def process_clients(options={})
    @debug = options[:debug]
    @project = options[:project]
    @file_name = options[:file_name]

    map_clients = {
      "nomfiscal"  => "name",
      "dirfiscal"  => "address",
      "dircli2"    => "address2",
      "pobfiscal"  => "city",
      "provifiscal"=> "province",
      "dtofiscal"  => "postalcode",
      "fecalta"    => "created_at",
      "e_mail"     => "email",
      "paginaweb"  => "website",
      "docpag"     => "payment_method",
      "codcli"     => "company_identifier"
    }

    result = CsvMapper::import(@file_name) do
      read_attributes_from_file
    end

    result.each do |result_line|

      next if result_line['nifcli'].nil?

      # check existing taxcodes in the project 
      client = @project.clients.find_by_taxcode(result_line['nifcli'])

      # if not found then it is a new taxcode
      client = Client.new(:project=> @project,
                          :invoice_format => 'signed_pdf',
                          :taxcode => result_line['nifcli'],
                          :terms => '0',
                          :currency => 'EUR' ) if client.nil?

      map_clients.each do |csv_field,client_field|
        puts "#{client_field} = #{csv_field} = #{result_line[csv_field]}" if @debug
        client[client_field] = result_line[csv_field].strip unless result_line[csv_field].nil?
      end

      if result_line['docpag'].upcase == 'R'
        client.payment_method = Invoice::PAYMENT_DEBIT
      else
        client.payment_method = Invoice::PAYMENT_TRANSFER
      end

      # deltete invalid email addresses
      client.email = '' unless client.email =~ /\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

      begin
        client.save!
        puts "====================================" if @debug
      rescue Exception => error
        puts "Error importing #{result_line}"
        raise error
      end

    end
  end

  def process_invoices(options={})
    @debug = options[:debug]
    @project = options[:project]
    @file_name = options[:file_name]

    map_invoices = {
      "fechacontable" => "date",
      "idfacv"        => "number",
      "observaciones" => "extra_info",
      "fecha"         => "created_at",
      "base"          => "import_in_cents",
      "docpag"        => "payment_method",
      "totapagar"     => "total_in_cents",
      "centrocoste"   => "accounting_cost"
    }


    result = CsvMapper::import(@file_name) do
      read_attributes_from_file
    end

    result.each do |result_line|

      next if result_line['idfacv'].nil?

      invoice = @project.issued_invoices.find_by_number(result_line['idfacv'])

      if invoice.nil?
        client = @project.clients.find_by_taxcode(result_line['nifcli'])
        if client.nil?
          puts "Client #{result_line['nifcli']} not found"
          next
        end
        invoice = IssuedInvoice.new(:project => @project,
                                    :client => client,
                                    :currency => 'EUR' 
                                   )
      end 

      map_invoices.each do |csv_field,field|
        puts "#{field} = #{csv_field} = #{result_line[csv_field]}" if @debug
        invoice[field] = result_line[csv_field].strip unless result_line[csv_field].nil?
      end

      invoice.due_date = result_line['fechacontable']

      invoice.date = Date.today if invoice.date.nil?

      invoice.invoice_lines << InvoiceLine.new(:quantity=>1, :description=>'aux', :price=>invoice.import_in_cents)
 

      begin
        invoice.save!
        puts "====================================" if @debug
      rescue Exception => error
        puts "Error importing #{result_line}"
        puts "Invoice #{invoice.inspect}"
        raise error
      end

    end
  end

end
