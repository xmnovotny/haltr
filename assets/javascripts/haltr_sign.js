function log(msg) {
  document.getElementById('console').value = document.getElementById('console').value + "\n" + msg;
}

function doSign(docment_url) {
  try {

    $.ajax({
      type: "GET",
    url: "/plugin_assets/haltr/javascripts/signature.js",
    dataType: "script",
    }).done(function() {
      alert('done')
      history.back(1);
    });

    var dataB64;

    $.ajax({
      url : document_url,
      success : function(dataB64){

        try {
          alert('Cridant a la signatura');
          var signature = sign( dataB64, 'SHA1withRSA', 'Adobe PDF', null);


        } catch(e) {
          log(getErrorMessage());
        }

      }
    });


  } catch(e) {
    log(getErrorMessage());
  }
  alert('dosign');
}
