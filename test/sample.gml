<?xml version="1.0" encoding="UTF-8"?>
<gml:FeatureCollection 
    xmlns:egb="ewidencjaGruntowIBudynkow:1.0" 
    xmlns:gml="http://www.opengis.net/gml/3.2" 
    xmlns:xlink="http://www.w3.org/1999/xlink">

    <gml:featureMember>
        <egb:EGB_DzialkaEwidencyjna gml:id="DZ.1">
            <egb:idDzialki>221208_2.0026.60/5</egb:idDzialki>
            <egb:numerKW>SL1S/00075286/3</egb:numerKW>
            <egb:poleEwidencyjne>0.0947</egb:poleEwidencyjne>
            
            <egb:JRG2 xlink:href="#JRG.1"/>

            <egb:punktGraniczny xlink:href="#P.1"/>
            <egb:punktGraniczny xlink:href="#P.2"/>
            
            </egb:EGB_DzialkaEwidencyjna>
    </gml:featureMember>

    <gml:featureMember>
        <egb:EGB_PunktGraniczny gml:id="P.1">
            <egb:oznaczenieWMaterialeZrodlowym>101</egb:oznaczenieWMaterialeZrodlowym>
            <egb:STB>ZRD</egb:STB>
            <egb:ISD>PZG</egb:ISD>
            <egb:SPD>TRK</egb:SPD>
            <egb:geometria>
                <gml:Point gml:id="P.1_GEO">
                    <gml:pos>5571170.08 6571520.10</gml:pos>
                </gml:Point>
            </egb:geometria>
            <egb:zrodloDanych>
                <egb:EGB_ZrodloDanych>
                    <egb:identyfikatorOperatuWgPZGIK>P.2212.2020.123</egb:identyfikatorOperatuWgPZGIK>
                </egb:EGB_ZrodloDanych>
            </egb:zrodloDanych>
        </egb:EGB_PunktGraniczny>
    </gml:featureMember>
    
    <gml:featureMember>
        <egb:EGB_PunktGraniczny gml:id="P.2">
            </egb:EGB_PunktGraniczny>
    </gml:featureMember>

    <gml:featureMember>
        <egb:EGB_JednostkaRejestrowaGruntow gml:id="JRG.1">
            <egb:idJednostkiRejestrowej>G.100</egb:idJednostkiRejestrowej>
            </egb:EGB_JednostkaRejestrowaGruntow>
    </gml:featureMember>

    <gml:featureMember>
        <egb:EGB_OsobaFizyczna gml:id="OS.10">
            <egb:imiePierwsze>Jan</egb:imiePierwsze>
            <egb:nazwisko>Kowalski</egb:nazwisko>
        </egb:EGB_OsobaFizyczna>
    </gml:featureMember>
    
    <gml:featureMember>
        <egb:EGB_Instytucja gml:id="IN.20">
            <egb:nazwaPelna>Skarb Państwa</egb:nazwaPelna>
        </egb:EGB_Instytucja>
    </gml:featureMember>

    <gml:featureMember>
        <egb:EGB_UdzialWeWlasnosci gml:id="UDZ.101">
            <egb:licznikUlamkaOkreslajacegoWartoscUdzialu>1</egb:licznikUlamkaOkreslajacegoWartoscUdzialu>
            <egb:mianownikUlamkaOkreslajacegoWartoscUdzialu>2</egb:mianownikUlamkaOkreslajacegoWartoscUdzialu>
            
            <egb:przedmiotUdzialuWlasnosci>
                <egb:EGB_JednostkaRejestrowa>
                    <egb:JRG xlink:href="#JRG.1"/>
                </egb:EGB_JednostkaRejestrowa>
            </egb:przedmiotUdzialuWlasnosci>

            <egb:podmiotUdzialuWlasnosci>
                <egb:EGB_Podmiot>
                    <egb:osobaFizyczna xlink:href="#OS.10"/>
                </egb:EGB_Podmiot>
            </egb:podmiotUdzialuWlasnosci>
        </egb:EGB_UdzialWeWlasnosci>
    </gml:featureMember>

    <gml:featureMember>
        <egb:EGB_UdzialWeWlasnosci gml:id="UDZ.102">
            <egb:licznikUlamkaOkreslajacegoWartoscUdzialu>1</egb:licznikUlamkaOkreslajacegoWartoscUdzialu>
            <egb:mianownikUlamkaOkreslajacegoWartoscUdzialu>2</egb:mianownikUlamkaOkreslajacegoWartoscUdzialu>
            
            <egb:przedmiotUdzialuWlasnosci>
                <egb:EGB_JednostkaRejestrowa>
                    <egb:JRG xlink:href="#JRG.1"/>
                </egb:EGB_JednostkaRejestrowa>
            </egb:przedmiotUdzialuWlasnosci>

            <egb:podmiotUdzialuWlasnosci>
                <egb:EGB_Podmiot>
                    <egb:instytucja1 xlink:href="#IN.20"/>
                </egb:EGB_Podmiot>
            </egb:podmiotUdzialuWlasnosci>
        </egb:EGB_UdzialWeWlasnosci>
    </gml:featureMember>

</gml:FeatureCollection>

