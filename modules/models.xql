xquery version "3.1";

module namespace models="http://exist.jmmc.fr/datamodels/models";

import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace lib="http://exist-db.org/xquery/html-templating/lib";
import module namespace config="http://exist.jmmc.fr/datamodels/config" at "config.xqm";

import module namespace jmmc-tap="http://exist.jmmc.fr/jmmc-resources/tap" at "/db/apps/jmmc-resources/content/jmmc-tap.xql";

(: List of models with id:url :)
declare variable $models:models := map {
(:    "OiDB":         map{"tap":"http://oidb.jmmc.fr/tap/", "table":"oidb"},:)
    "OiDB":         map{"tap":"http://tap.jmmc.fr/vollt/tap/", "table":"oidb"},
    "GetStarV5":      map{"votable":"http://jmmc.fr/~sclws/getstar/sclwsGetStarProxy.php?star=Sirius"},
    "GetStarV6":      map{"votable":"http://jmmc.fr/~bourgesl/getstar/sclwsGetStarProxy.php?star=Sirius"},
    "ObsPortal":    map{"votable":"http://obs.jmmc.fr/search.votable?instrument=AMBER&amp;instrument_mode=29"},
    "BadCal":       map{"votable":"http://apps.jmmc.fr/badcal-dsa/SubmitCone?DSACATTAB=badcal.valid_stars&amp;RA=0.0&amp;DEC=0.0&amp;SR=180.0"},
    "JSDC":         map{},
    "SearchCal":    map{},
    "Simbad":       map{},
(:    "SPICA":        map{"tap":"http://192.168.1.117:8008/vollt/tap/", "table":"spica"},:)
    "SPICA":        map{"votable":"http://jmmc.fr/~mellag/spica-before-tapserver.vot"},
    "TAP_SCHEMA.tables": map{}
};

declare variable $models:model-type-color := map {
  "tap":"info",
  "votable":"success",
  "":"danger"
};

declare variable  $models:cache-name := "cachemodels";

(:~
 : List models.
 : 
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function models:list($node as node(), $model as map(*)) {
    <div class="panel-group" id="m-accordion" role="tablist" aria-multiselectable="true">
        { sort(map:keys($models:models)) ! models:list(.) }
    </div>
};

(:~
 : Show models content aggregation.
 : 
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function models:mix($node as node(), $model as map(*)) {
    
    let $group-by-attr := request:get-parameter("group-by", "ucd")
    
    let $votables-map := map:merge( for $name in map:keys($models:models)
        let $model := $models:models($name)
        let $type := models:get-type($model)
        let $url := $type ! $model(.)
        return switch ($type) case "tap" case "votable" return map{$name : models:get-votable($model)} default return ()
        )
    let $table-names := map:keys($votables-map)
    let $votables:= $table-names ! $votables-map(.)
    let $fields-attrs := distinct-values($votables//*:FIELD/@*!name())[not(.=$group-by-attr)]
    
    let $columns := $votables//*:FIELD    
    return (<p>Group by : {$fields-attrs ! <a href="?group-by={.}">&#160;{.}&#160;</a> } &#160;<a href="./modules/to_xml.xql?group-by={$group-by-attr}">( Export as xml )</a></p>,
        
        <table id="mixedtable" class="display table table-bordered nowrap">
        <thead><tr>
            <th>{$group-by-attr}</th><th>#</th>
            {$fields-attrs!<th>{.}</th>}
            {$table-names!<th>{.}</th>}
            <th>Descriptions</th>
            </tr></thead>
        <tbody>
        {
            for $field in map:for-each($votables-map, function ($k, $v){$v//*:FIELD}) group by $col-name := data($field/@*[name()=$group-by-attr])
            return 
                <tr>
                    <th>{$col-name} </th>
                    <th title="Distinct field counts">{count($field)}</th>
                    <!--th>{$col-name}</th-->
                    {
                    for $attr in $fields-attrs 
                    return 
                        <td>{
                            let $values := $field/@*[name(.)=$attr]
                            return if(count($values)>1) then <ul>{distinct-values($values)!<li>{.}</li>}</ul> else data($values)
                        }</td>
                    }
                {
                    for $name in $table-names let $votable:=$votables-map($name) 
                    return 
                        <td>{if($name[$col-name=$votable//*:FIELD/@*[name()=$group-by-attr]]) then "X" else ()}</td>
                }
                <td>{
                    let $descs := distinct-values($field/*:DESCRIPTION)
                    return if(true() or count($descs)>1) then <ul>{distinct-values($descs) !<li>{.}</li>}</ul> else $descs
                }</td>
                </tr>
    }</tbody></table>
    
    )
};





declare function models:get-type($model as map(*)){
    ("tap","votable")[.=map:keys($model)]
}; 

declare function models:list($name) 
{
    let $model := $models:models($name)
    let $type := models:get-type($model)
    let $url := $type ! $model(.)
    let $votable := switch ($type)
        case "tap" case "votable" return models:get-votable($model)
        default return ()
    let $votable-summary := models:votable-summary-info($votable, false())
    let $votable-columns-info := models:votable-columns-info($votable)

    let $badges := $type ! <span class="pull-right badge badge-{$models:model-type-color(.)}">{substring(., 1, 3)}</span>
    let $cid :=concat("collapse", $name)
    let $hid :=concat("heading",  $name)
    return 
    <div class="panel panel-default">
        <div class="panel-heading" role="tab" id="{$hid}">
          <h4 class="panel-title"> <a class="collapsed" role="button" data-toggle="collapse" data-parent="#--m-accordion" href="#{$cid}" aria-expanded="false" aria-controls="{$cid}">  
          <b>{$name}</b> <span class="pull-right">{$votable-summary} {$badges}</span> 
          </a> </h4>
        </div>
        <div id="{$cid}" class="panel-collapse collapse" role="tabpanel" aria-labelledby="{$hid}">
          <div class="panel-body">
            {if($url!="") then <em><b>URL:</b> {$url}</em> else ()}
            <br/>
            {$votable-columns-info}
          </div>
        </div>
    </div>
};

declare function models:get-votable($model) {
    let $type:=models:get-type($model)
    let $url:=$model($type)
    let $vot := cache:get($models:cache-name, $url)
    return if(exists($vot)) then $vot
    else
        let $vot := switch ($type)
            case "votable" return doc($url)
            case "tap" return jmmc-tap:tap-adql-query($url||"/sync", "SELECT * from " ||$model("table"), 1)
            default return ()
        let $store := if(exists($vot)) then cache:put($models:cache-name, $url, $vot) else ()
        return $vot
};

declare function models:votable-summary-info($votable, $table-mode as xs:boolean){
    if(exists($votable)) then 
        let $columns := ["Version", "#params", "#fields", "#groups"]
        let $data := map{
            "#params":count($votable//*:PARAM),
            "#fields":count($votable//*:FIELD),
            "#groups":count($votable//*:GROUP),
            "Version":namespace-uri($votable/*)
        }
        return switch ($table-mode)
            case true() return <table class="table table-border"><tr>{$columns?*!<th>{.}</th>}</tr><tr>{$columns?*!<td>{$data(.)}</td>}</tr></table>
            default return $columns?* ! <span>&#160;{.}=<em>{$data(.)}</em>&#160;</span>
    else
        ()
};


declare function models:votable-columns-info($votables){
    for $votable in $votables return 
        let $fields := $votable//*:FIELD
        let $attributes := distinct-values($fields/@*!name(.))[not(.="name")]
        let $params := $votable//*:PARAM
        let $p-attributes := distinct-values($params/@*!name(.))[not(.="name")]
        return <div>
            <h3>Fields</h3>
            <table class="display table table-bordered datatable nowrap">
                <thead><tr><th>name</th>{$fields!<th> {data(@name) }</th>} </tr></thead>
                <tbody>
                {for $a in $attributes return <tr><td>{data($a)}</td> {$fields ! element td {data(./@*[name()=$a])} } </tr>}
                </tbody>
            </table>
            {if($params) then (<h3>Params</h3>,
            <table class="display table table-bordered datatable nowrap">
                <thead><tr><th>name</th>{$params!<th> {data(@name) }</th>} </tr></thead>
                <tbody>
                {for $a in $p-attributes return <tr><td>{data($a)}</td> {$params ! element td {data(./@*[name()=$a])} } </tr>}
                </tbody>
            </table>) else ()
            }
        </div>
};

