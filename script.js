'strict'

//This below is fetching the my AZ Func everytime someone loads into website.

window.addEventListener('load', function(){

    fetch('crc-func-app.azurewebsites.net',{

        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({count: 1 })

})
})