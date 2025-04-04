*** Settings ***
Documentation     End-to-End Test Suite for Inventory Management with Order Fulfillment
...               Tests product lifecycle, order processing, and inventory reconciliation
...               Includes positive, negative, missing parameters, and edge case validations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup Manager Session
    [Documentation]     Create API session and authenticate with manager credentials
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${MANAGER_TOKEN}    ${token}
    Create Directory    ${RESULTS_DIR}

Generate Warehouse Data
    [Arguments]         ${name_suffix}=${EMPTY}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Warehouse ${name_suffix} ${timestamp}
    ...                 address=456 Test Ave ${name_suffix}
    ...                 acreage=6000
    RETURN            ${warehouse_data}

Generate Rack Data
    [Arguments]         ${warehouse_id}    ${capacity}=${MAX_QUANTITY}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Generate Master Product Data
    [Arguments]         ${warehouse_id}    ${name}=${NONE}    ${barcode}=${NONE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${master_data}=     Create Dictionary
    ...                 name=${name if name is not NONE else "Master ${timestamp}"}
    ...                 capacity=500
    ...                 method=FIFO
    ...                 stogareTime=30
    ...                 image=https://example.com/master.jpg
    ...                 warehouseId=${warehouse_id}
    ...                 productCategoryId=1
    ...                 supplierIds=[1]
    ...                 purchasePrice=25.00
    ...                 salePrice=55.00
    ...                 retailPrice=65.00
    ...                 barCode=${barcode if barcode is not NONE else "BAR-M${timestamp}"}
    ...                 VAT=10
    ...                 DVT=unit
    ...                 packing=box
    ...                 length=15
    ...                 width=15
    ...                 height=15
    ...                 itemCode=ITEM-${timestamp}
    ...                 description=Test master product for orders
    ...                 isActive=${TRUE}
    ...                 discount=5
    ...                 isResources=${FALSE}
    ...                 availableQuantity=2000
    RETURN            ${master_data}

Generate Product Data
    [Arguments]         ${warehouse_id}    ${master_id}    ${rack_id}    ${quantity}=1000    ${barcode}=${NONE}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Order Product ${timestamp}
    ...                 totalQuantity=${quantity}
    ...                 expectedQuantity=${quantity}
    ...                 importDate=${CURRENT_DATE}
    ...                 cost=25.00
    ...                 salePrice=55.00
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=2025-12-31T00:00:00Z
    ...                 productCode=ORD-${timestamp}
    ...                 idRackReallocate=${rack_id}
    ...                 imageProduct=https://example.com/order-product.jpg
    ...                 imageQRCode=https://example.com/qr-order.jpg
    ...                 imageBarcode=https://example.com/barcode-order.jpg
    ...                 blockId=1
    ...                 supplierId=1
    ...                 productCategoryId=1
    ...                 rackId=${rack_id}
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=1
    ...                 packageId=1
    ...                 masterProductId=${master_id}
    ...                 note=Product for order fulfillment
    ...                 barCode=${barcode if barcode is not NONE else "BAR-P${timestamp}"}
    RETURN            ${product_data}

Create Warehouse
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /warehouses/create    json=${warehouse_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Rack
    [Arguments]         ${rack_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /racks/create    json=${rack_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Master Product
    [Arguments]         ${master_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /master-products/create    json=${master_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Create Product
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /products/create    json=${product_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Add Product To Rack
    [Arguments]         ${rack_id}    ${product_ids}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${rack_data}=       Create Dictionary    rackId=${rack_id}    productIds=${product_ids}
    ${response}=        POST On Session    vkho    /products/add/rack    json=${rack_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Update Product For Order
    [Documentation]     Update product quantity and status for order fulfillment
    [Arguments]         ${product_id}    ${quantity}    ${status}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${update_data}=     Create Dictionary
    ...                 id=${product_id}
    ...                 totalQuantity=${quantity}
    ...                 status=${status}
    ...                 orderId=2
    ...                 note=Updated for order fulfillment
    ${response}=        POST On Session    vkho    /products/update    json=${update_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Get Inventory
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session    vkho    /products/get-inventory    params=warehouseId=${warehouse_id}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Reconcile Inventory
    [Documentation]     Reconcile inventory by checking total quantities
    [Arguments]         ${warehouse_id}    ${product_ids}    ${expected_totals}
    ${status}    ${inventory}=    Get Inventory    ${warehouse_id}
    Should Be Equal As Integers    ${status}    200
    ${found_count}=     Set Variable    0
    FOR    ${item}    IN    @{inventory}
        ${item_id}=     Evaluate    str(${item}[id]) if 'id' in ${item} else None
        ${index}=       Get Index From List    ${product_ids}    ${item_id}
        IF    ${index} >= 0
            ${expected}=    Get From List    ${expected_totals}    ${index}
            Should Be Equal As Integers    ${item}[totalQuantity]    ${expected}
            ...                            Mismatch: ${item}[totalQuantity] vs ${expected} for ${item_id}
            ${found_count}=    Evaluate    ${found_count} + 1
        END
    END
    Should Be Equal As Integers    ${found_count}    ${${product_ids}.__len__()}
    ...                            Not all products found in inventory: ${found_count} vs ${${product_ids}.__len__()}

Delete Product
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /products/delete/${product_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete MasterProduct
    [Arguments]         ${master_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /master-products/delete/${master_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete Rack
    [Arguments]         ${rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /racks/delete/${rack_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete Warehouse
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /warehouses/delete/${warehouse_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

*** Test Cases ***
01 - Inventory Management with Order Fulfillment and Reconciliation
    [Documentation]     End-to-end test for inventory with order fulfillment and stock reconciliation
    [Tags]              inventory    products    master-products    orders    validation

    Setup Manager Session
    Log                 Manager session established

    # Setup Warehouses and Racks
    ${wh1_data}=        Generate Warehouse Data    Main
    ${wh1_id}    ${wh1_response}=    Create Warehouse    ${wh1_data}
    Set Global Variable  ${TEST_WAREHOUSE1_ID}    ${wh1_id}
    ${rack1_data}=      Generate Rack Data    ${TEST_WAREHOUSE1_ID}
    ${rack1_id}    ${rack1_response}=    Create Rack    ${rack1_data}
    Set Global Variable  ${TEST_RACK1_ID}    ${rack1_id}
    Log                 Created Warehouse 1: ${TEST_WAREHOUSE1_ID}, Rack: ${TEST_RACK1_ID}

    ${wh2_data}=        Generate Warehouse Data    Backup
    ${wh2_id}    ${wh2_response}=    Create Warehouse    ${wh2_data}
    Set Global Variable  ${TEST_WAREHOUSE2_ID}    ${wh2_id}
    ${rack2_data}=      Generate Rack Data    ${TEST_WAREHOUSE2_ID}
    ${rack2_id}    ${rack2_response}=    Create Rack    ${rack2_data}
    Set Global Variable  ${TEST_RACK2_ID}    ${rack2_id}
    Log                 Created Warehouse 2: ${TEST_WAREHOUSE2_ID}, Rack: ${TEST_RACK2_ID}

    # Positive - Create Master Products
    ${master1_data}=    Generate Master Product Data    ${TEST_WAREHOUSE1_ID}
    ${status_m1}    ${master1_response}=    Create Master Product    ${master1_data}
    Should Be Equal As Integers    ${status_m1}    201
    Set Global Variable  ${TEST_MASTER_ID1}    ${master1_response}[id]
    Log                 Created Master Product 1: ${TEST_MASTER_ID1}

    ${master2_data}=    Generate Master Product Data    ${TEST_WAREHOUSE2_ID}
    ${status_m2}    ${master2_response}=    Create Master Product    ${master2_data}
    Should Be Equal As Integers    ${status_m2}    201
    Set Global Variable  ${TEST_MASTER_ID2}    ${master2_response}[id]
    Log                 Created Master Product 2: ${TEST_MASTER_ID2}

    # Positive - Create Products
    ${prod1_data}=      Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    1500
    ${status_p1}    ${prod1_response}=    Create Product    ${prod1_data}
    Should Be Equal As Integers    ${status_p1}    201
    Set Global Variable  ${TEST_PRODUCT_ID1}    ${prod1_response}[id]
    Log                 Created Product 1: ${TEST_PRODUCT_ID1}

    ${prod2_data}=      Generate Product Data    ${TEST_WAREHOUSE2_ID}    ${TEST_MASTER_ID2}    ${TEST_RACK2_ID}    800
    ${status_p2}    ${prod2_response}=    Create Product    ${prod2_data}
    Should Be Equal As Integers    ${status_p2}    201
    Set Global Variable  ${TEST_PRODUCT_ID2}    ${prod2_response}[id]
    Log                 Created Product 2: ${TEST_PRODUCT_ID2}

    # Negative - Invalid Master Product ID
    ${invalid_data}=    Generate Product Data    ${TEST_WAREHOUSE1_ID}    9999    ${TEST_RACK1_ID}
    ${status_p3}    ${prod3_response}=    Create Product    ${invalid_data}
    Should Be Equal As Integers    ${status_p3}    400
    Should Contain    ${prod3_response}[message]    masterProductId    ignore_case=True
    Log                 Prevented creation with invalid masterProductId

    # Missing Parameter - No warehouseId
    ${no_wh_data}=      Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}
    Remove From Dictionary    ${no_wh_data}    warehouseId
    ${status_p4}    ${prod4_response}=    Create Product    ${no_wh_data}
    Should Be Equal As Integers    ${status_p4}    400
    Should Contain    ${prod4_response}[message]    warehouseId    ignore_case=True
    Log                 Prevented creation without warehouseId

    # Positive - Assign Products to Racks
    ${status_rack1}    ${rack1_response}=    Add Product To Rack    ${TEST_RACK1_ID}    [${TEST_PRODUCT_ID1}]
    Should Be Equal As Integers    ${status_rack1}    201
    Log                 Assigned Product 1 to Rack ${TEST_RACK1_ID}

    # Edge Case - Assign Product to Full Rack (assuming capacity check)
    ${prod_full_data}=  Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${MAX_QUANTITY}
    ${status_p5}    ${prod5_response}=    Create Product    ${prod_full_data}
    Should Be Equal As Integers    ${status_p5}    201
    ${full_prod_id}=    Set Variable    ${prod5_response}[id]
    ${status_rack2}    ${rack2_response}=    Add Product To Rack    ${TEST_RACK1_ID}    [${full_prod_id}]
    Should Be Equal As Integers    ${status_rack2}    400    # Assuming capacity limit
    Should Contain    ${rack2_response}[message]    capacity    ignore_case=True
    Log                 Prevented assignment to full rack

    # Positive - Fulfill Order by Updating Product
    ${status_upd1}    ${upd1_response}=    Update Product For Order    ${TEST_PRODUCT_ID1}    1000    SHIPPED
    Should Be Equal As Integers    ${status_upd1}    201
    Log                 Fulfilled order for Product 1, reduced to 1000 units

    # Negative - Over-Fulfill Order
    ${status_upd2}    ${upd2_response}=    Update Product For Order    ${TEST_PRODUCT_ID1}    2000    SHIPPED
    Should Be Equal As Integers    ${status_upd2}    400
    Should Contain    ${upd2_response}[message]    quantity    ignore_case=True
    Log                 Prevented over-fulfillment of Product 1

    # Edge Case - Reduce to Minimum Quantity
    ${status_upd3}    ${upd3_response}=    Update Product For Order    ${TEST_PRODUCT_ID2}    ${MIN_QUANTITY}    SHIPPED
    Should Be Equal As Integers    ${status_upd3}    201
    Log                 Reduced Product 2 to minimum quantity ${MIN_QUANTITY}

    # Missing Parameter - Update without Status
    ${no_status_data}=  Create Dictionary    id=${TEST_PRODUCT_ID1}    totalQuantity=900    orderId=2
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /products/update    json=${no_status_data}    headers=${headers}    expected_status=400
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    status    ignore_case=True
    Log                 Prevented update without status

    # Positive - Reconcile Inventory
    ${product_ids_wh1}=    Create List    ${TEST_PRODUCT_ID1}    ${full_prod_id}
    ${expected_wh1}=       Create List    1000    ${MAX_QUANTITY}
    Reconcile Inventory    ${TEST_WAREHOUSE1_ID}    ${product_ids_wh1}    ${expected_wh1}
    Log                 Reconciled Warehouse 1 inventory

    ${product_ids_wh2}=    Create List    ${TEST_PRODUCT_ID2}
    ${expected_wh2}=       Create List    ${MIN_QUANTITY}
    Reconcile Inventory    ${TEST_WAREHOUSE2_ID}    ${product_ids_wh2}    ${expected_wh2}
    Log                 Reconciled Warehouse 2 inventory

    # Edge Case - Zero Stock After Fulfillment
    ${status_upd4}    ${upd4_response}=    Update Product For Order    ${TEST_PRODUCT_ID2}    0    SHIPPED
    Should Be Equal As Integers    ${status_upd4}    201
    ${product_ids_wh2_zero}=    Create List    ${TEST_PRODUCT_ID2}
    ${expected_wh2_zero}=       Create List    0
    Reconcile Inventory    ${TEST_WAREHOUSE2_ID}    ${product_ids_wh2_zero}    ${expected_wh2_zero}
    Log                 Validated zero stock for Product 2

    # Negative - Unauthorized Update (No Token)
    ${no_auth_headers}=    Create Dictionary    Content-Type=application/json
    ${update_data}=        Create Dictionary    id=${TEST_PRODUCT_ID1}    totalQuantity=800    status=SHIPPED
    ${response}=           POST On Session    vkho    /products/update    json=${update_data}    headers=${no_auth_headers}    expected_status=401
    ${json}=               Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    authorization    ignore_case=True
    Log                 Prevented unauthorized update

    # Cleanup
    Delete Product    ${TEST_PRODUCT_ID1}
    Delete Product    ${TEST_PRODUCT_ID2}
    Delete Product    ${full_prod_id}
    Delete MasterProduct    ${TEST_MASTER_ID1}
    Delete MasterProduct    ${TEST_MASTER_ID2}
    Delete Rack    ${TEST_RACK1_ID}
    Delete Rack    ${TEST_RACK2_ID}
    Delete Warehouse    ${TEST_WAREHOUSE1_ID}
    Delete Warehouse    ${TEST_WAREHOUSE2_ID}
    Log                 Cleaned up all test resources